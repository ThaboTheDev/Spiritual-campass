import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_providers.dart';
import '../../core/config/app_config.dart';
import '../../data/local/preferences_store.dart';
import 'membership_api.dart';
import 'membership_models.dart';
import 'session_store.dart';

/// Every screen the gate can show, in the order a new member meets them.
///
/// The whole app — the compass included — sits behind this: `AppShell` is
/// built only in [ready].
enum AuthPhase {
  /// Restoring the stored session / first `/api/me`.
  loading,

  /// Log in or create an account.
  signedOut,

  /// Signed up, waiting for the confirmation link to be opened.
  awaitingEmailConfirm,

  /// The server says `must_change_password`: nothing else works until a new
  /// password is set. Reached online *and* from the cache, never skipped.
  mustChangePassword,

  /// First login of a trial account: the feature list and "Pay now".
  trialIntro,

  /// The server says there is no access (trial over, or past the grace
  /// period). "Pay now" (outside store builds) and "Log out".
  paywall,

  /// Signed in, offline, and the cache cannot vouch for the member. Not a
  /// paywall: nothing is known, so nothing is claimed.
  offlineLocked,

  /// Access confirmed — the app itself.
  ready,
}

/// Which half of the first screen is showing.
enum AuthMode { logIn, createAccount }

/// Errors shown inline, mapped to strings by the widgets.
enum MembershipError {
  none,
  badEmail,
  missingPassword,
  shortPassword,
  passwordMismatch,
  invalidCredentials,
  emailNotConfirmed,
  alreadyRegistered,
  weakPassword,
  rateLimited,
  offline,
  authFailed,
  changePasswordFailed,
  checkoutFailed,
  alreadySubscribed,
  cancelFailed,
  openFailed,
}

/// Everything the gate and the account screen need.
class MembershipState {
  const MembershipState({
    this.phase = AuthPhase.loading,
    this.mode = AuthMode.logIn,
    this.email = '',
    this.entitlement,
    this.fromCache = false,
    this.busy = false,
    this.error = MembershipError.none,
    this.confirmingCancel = false,
    this.awaitingPayment = false,
    this.cancelledNotice = false,
    this.recoverySent = false,
    this.confirmationResent = false,
    this.passwordChanged = false,
  });

  final AuthPhase phase;
  final AuthMode mode;
  final String email;
  final Entitlement? entitlement;

  /// The entitlement came from the offline cache, not the server.
  final bool fromCache;
  final bool busy;
  final MembershipError error;

  /// First tap of "Cancel subscription" done; second confirms.
  final bool confirmingCancel;

  /// PayFast was opened; `/api/me` is being re-checked.
  final bool awaitingPayment;

  /// Server confirmed a cancellation this session.
  final bool cancelledNotice;

  /// "Forgot password" mail was accepted by Supabase.
  final bool recoverySent;

  /// The confirmation mail was sent again.
  final bool confirmationResent;

  /// The password was changed this session.
  final bool passwordChanged;

  /// Whether a session exists (the member is past the first screen).
  bool get isSignedIn =>
      phase == AuthPhase.mustChangePassword ||
      phase == AuthPhase.trialIntro ||
      phase == AuthPhase.paywall ||
      phase == AuthPhase.offlineLocked ||
      phase == AuthPhase.ready;

  /// Whether the member currently has access (server or valid cache).
  bool get hasAccess {
    final Entitlement? e = entitlement;
    if (e == null) {
      return false;
    }
    return fromCache ? e.cachedAccessValid() : e.access;
  }

  /// Whether the admin area may be shown. The server enforces it too.
  bool get isAdmin => entitlement?.isAdmin ?? false;

  MembershipState copyWith({
    AuthPhase? phase,
    AuthMode? mode,
    String? email,
    Entitlement? entitlement,
    bool clearEntitlement = false,
    bool? fromCache,
    bool? busy,
    MembershipError? error,
    bool? confirmingCancel,
    bool? awaitingPayment,
    bool? cancelledNotice,
    bool? recoverySent,
    bool? confirmationResent,
    bool? passwordChanged,
  }) {
    return MembershipState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      email: email ?? this.email,
      entitlement: clearEntitlement ? null : entitlement ?? this.entitlement,
      fromCache: fromCache ?? this.fromCache,
      busy: busy ?? this.busy,
      error: error ?? this.error,
      confirmingCancel: confirmingCancel ?? this.confirmingCancel,
      awaitingPayment: awaitingPayment ?? this.awaitingPayment,
      cancelledNotice: cancelledNotice ?? this.cancelledNotice,
      recoverySent: recoverySent ?? this.recoverySent,
      confirmationResent: confirmationResent ?? this.confirmationResent,
      passwordChanged: passwordChanged ?? this.passwordChanged,
    );
  }
}

/// The one state machine behind the gate: e-mail + password sign-in,
/// `/api/me`, the forced password change, PayFast checkout / cancel and the
/// offline entitlement cache.
///
/// Rules it must keep:
/// * the server decides access; this only mirrors it,
/// * never sign out because the device is offline — only a 4xx on the refresh
///   grant (or a 401 from our API) signs out locally,
/// * `403 password_change_required` means "go to the change-password screen",
///   never "sign out",
/// * offline, a cached entitlement is good until its paid-through / trial end
///   date, unless the cache says the password must be changed.
class MembershipController extends Notifier<MembershipState> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Shortest password the app will send. Supabase may demand more; a
  /// `weak_password` answer is shown as its own message.
  static const int minPasswordLength = 8;

  SupabaseAuthClient get _auth => ref.read(supabaseAuthClientProvider);
  MembershipApiClient get _api => ref.read(membershipApiClientProvider);
  SessionStore get _sessions => ref.read(sessionStoreProvider);
  PreferencesStore get _prefs => ref.read(preferencesStoreProvider);

  AuthSession? _session;

  @override
  MembershipState build() {
    Future<void>.microtask(restoreSession);
    return const MembershipState(phase: AuthPhase.loading, busy: true);
  }

  // ------------------------------------------------------------- first run

  /// Reads the stored session and asks the server where the member stands.
  Future<void> restoreSession() async {
    final AuthSession? session = await _sessions.read();
    if (session == null) {
      state = const MembershipState(phase: AuthPhase.signedOut);
      return;
    }
    _session = session;
    state = MembershipState(
      phase: AuthPhase.loading,
      email: session.email,
      busy: true,
    );
    await refreshEntitlement();
  }

  // --------------------------------------------------------------- sign-in

  /// Switches between "Log in" and "Create account".
  void setMode(AuthMode mode) {
    if (state.busy) {
      return;
    }
    state = state.copyWith(
      mode: mode,
      error: MembershipError.none,
      recoverySent: false,
    );
  }

  /// `POST /auth/v1/token?grant_type=password`, then `/api/me`.
  Future<void> logIn(String email, String password) async {
    if (state.busy) {
      return;
    }
    final String trimmed = email.trim();
    if (!_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(error: MembershipError.badEmail);
      return;
    }
    if (password.isEmpty) {
      state = state.copyWith(error: MembershipError.missingPassword);
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      email: trimmed,
      recoverySent: false,
    );
    try {
      final AuthSession session = await _auth.signInWithPassword(trimmed, password);
      await _adoptSession(session);
      await refreshEntitlement();
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on AuthException catch (error) {
      if (error.kind == AuthErrorKind.emailNotConfirmed) {
        state = state.copyWith(
          phase: AuthPhase.awaitingEmailConfirm,
          busy: false,
          error: MembershipError.emailNotConfirmed,
        );
        return;
      }
      state = state.copyWith(busy: false, error: _authError(error.kind));
    }
  }

  /// `POST /auth/v1/signup`. With confirmation ON there is no session yet.
  Future<void> signUp(String email, String password) async {
    if (state.busy) {
      return;
    }
    final String trimmed = email.trim();
    if (!_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(error: MembershipError.badEmail);
      return;
    }
    if (password.length < minPasswordLength) {
      state = state.copyWith(error: MembershipError.shortPassword);
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      email: trimmed,
      recoverySent: false,
    );
    try {
      final SignUpResult result = await _auth.signUp(trimmed, password);
      final AuthSession? session = result.session;
      if (session == null) {
        state = state.copyWith(
          phase: AuthPhase.awaitingEmailConfirm,
          busy: false,
          confirmationResent: false,
        );
        return;
      }
      await _adoptSession(session);
      await refreshEntitlement();
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: _authError(error.kind));
    }
  }

  /// `POST /auth/v1/resend {type:"signup"}`.
  Future<void> resendConfirmation() async {
    if (state.busy || state.email.isEmpty) {
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      confirmationResent: false,
    );
    try {
      await _auth.resendConfirmation(state.email);
      state = state.copyWith(busy: false, confirmationResent: true);
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: _authError(error.kind));
    }
  }

  /// `POST /auth/v1/recover?redirect_to={kSiteUrl}/reset`.
  ///
  /// Supabase answers 200 even for an address it does not know (it will not
  /// confirm who has an account), so the confirmation message is deliberately
  /// neutral.
  Future<void> recoverPassword(String email) async {
    if (state.busy) {
      return;
    }
    final String trimmed = email.trim();
    if (!_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(error: MembershipError.badEmail);
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      email: trimmed,
      recoverySent: false,
    );
    try {
      await _auth.recover(trimmed);
      state = state.copyWith(busy: false, recoverySent: true);
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: _authError(error.kind));
    }
  }

  /// Back to the first screen (from "awaiting confirmation").
  void backToLogin() {
    state = state.copyWith(
      phase: AuthPhase.signedOut,
      mode: AuthMode.logIn,
      error: MembershipError.none,
      confirmationResent: false,
      busy: false,
    );
  }

  /// Signs out locally and drops everything cached for this member.
  ///
  /// The per-account "trial page seen" flags stay: they are keyed by user id,
  /// so the page still shows once per account, not once per install.
  Future<void> signOut() async {
    _session = null;
    await _sessions.clear();
    await _prefs.saveCachedEntitlementJson(null);
    await ref.read(centresCacheProvider).clear();
    state = const MembershipState(phase: AuthPhase.signedOut);
  }

  // ------------------------------------------------------- password change

  /// `POST /api/account/password`, then log in again with the new password.
  ///
  /// Used both by the forced screen and voluntarily from the account screen.
  Future<void> changePassword(String newPassword, String confirmation) async {
    if (state.busy) {
      return;
    }
    if (newPassword.length < minPasswordLength) {
      state = state.copyWith(error: MembershipError.shortPassword);
      return;
    }
    if (newPassword != confirmation) {
      state = state.copyWith(error: MembershipError.passwordMismatch);
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      passwordChanged: false,
    );
    try {
      final String token = await _freshAccessToken();
      await _api.changePassword(token, newPassword);
      // The old session may be revoked by the password change, so get a new
      // one straight away rather than waiting for the next 401.
      final AuthSession session =
          await _auth.signInWithPassword(state.email, newPassword);
      await _adoptSession(session);
      state = state.copyWith(busy: false, passwordChanged: true);
      await refreshEntitlement();
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on MembershipApiException catch (error) {
      if (error.isUnauthorised) {
        await signOut();
        return;
      }
      state = state.copyWith(
        busy: false,
        error: error.code == 'weak_password'
            ? MembershipError.weakPassword
            : MembershipError.changePasswordFailed,
      );
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: _authError(error.kind));
    } on _SignedOut {
      // Already signed out.
    }
  }

  // ----------------------------------------------------------- entitlement

  /// `GET /api/me`; falls back to the cached entitlement while offline.
  ///
  /// [silent] skips the "busy" flash, for the resume / timer re-checks.
  Future<void> refreshEntitlement({
    bool afterPayment = false,
    bool silent = false,
  }) async {
    if (_session == null) {
      return;
    }
    if (!silent) {
      state = state.copyWith(
        busy: true,
        error: MembershipError.none,
        awaitingPayment: afterPayment,
        confirmingCancel: false,
      );
    }
    try {
      final String token = await _freshAccessToken();
      final (Entitlement entitlement, Map<String, dynamic> raw) =
          await _api.me(token);
      await _prefs.saveCachedEntitlementJson(
        jsonEncode(entitlement.toCacheJson(raw)),
      );
      _applyEntitlement(
        entitlement,
        fromCache: false,
        afterPayment: afterPayment,
      );
    } on MembershipOffline {
      _useCache();
    } on MembershipApiException catch (error) {
      if (error.isPasswordChangeRequired) {
        // Never a sign-out: the member simply has to set a password first.
        state = state.copyWith(
          phase: AuthPhase.mustChangePassword,
          busy: false,
          error: MembershipError.none,
        );
        return;
      }
      if (error.isUnauthorised) {
        await signOut();
        return;
      }
      _useCache();
    } on _SignedOut {
      // Refresh token rejected: already signed out.
    }
  }

  /// Re-check used by the app-resume hook and the periodic timer.
  Future<void> recheckAccess() => refreshEntitlement(
        afterPayment: state.awaitingPayment,
        silent: !state.awaitingPayment,
      );

  /// "Start using the app" on the trial page.
  Future<void> acknowledgeTrialIntro() async {
    await _prefs.markTrialIntroSeen(_trialIntroKey);
    if (state.phase == AuthPhase.trialIntro) {
      state = state.copyWith(
        phase: AuthPhase.ready,
        error: MembershipError.none,
      );
    }
  }

  void _applyEntitlement(
    Entitlement entitlement, {
    required bool fromCache,
    bool afterPayment = false,
    MembershipError error = MembershipError.none,
  }) {
    final bool access =
        fromCache ? entitlement.cachedAccessValid() : entitlement.access;
    state = state.copyWith(
      phase: _phaseFor(entitlement, fromCache: fromCache),
      entitlement: entitlement,
      fromCache: fromCache,
      busy: false,
      error: error,
      email: entitlement.email.isNotEmpty ? entitlement.email : state.email,
      awaitingPayment: afterPayment && !access,
    );
  }

  /// The gate decision, kept in one place so it can be reasoned about (and
  /// tested) on its own.
  AuthPhase _phaseFor(Entitlement e, {required bool fromCache}) {
    // A cached "must change password" is still a hard stop: the member has
    // to go online to fix it, so no offline entry.
    if (e.mustChangePassword) {
      return AuthPhase.mustChangePassword;
    }
    final bool access = fromCache ? e.cachedAccessValid() : e.access;
    if (!access) {
      // Offline we do not know anything new, so we do not claim the trial is
      // over — we ask for a connection instead.
      return fromCache ? AuthPhase.offlineLocked : AuthPhase.paywall;
    }
    if (e.state == EntitlementState.trial && !_prefs.trialIntroSeen(_trialIntroKey)) {
      return AuthPhase.trialIntro;
    }
    return AuthPhase.ready;
  }

  void _useCache({MembershipError error = MembershipError.offline}) {
    final Entitlement? cached = _readCache();
    if (cached == null) {
      state = state.copyWith(
        phase: AuthPhase.offlineLocked,
        busy: false,
        error: error,
      );
      return;
    }
    _applyEntitlement(cached, fromCache: true, error: error);
  }

  Entitlement? _readCache() {
    final String? raw = _prefs.cachedEntitlementJson;
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Entitlement.fromCacheJson(decoded);
      }
    } catch (_) {
      // Corrupt cache: ignore.
    }
    return null;
  }

  // --------------------------------------------------------------- PayFast

  /// Opens the signed PayFast checkout in the external browser. Hidden in
  /// store builds; guarded here as well.
  Future<void> startCheckout() async {
    if (kStoreBuild || _session == null || state.busy) {
      return;
    }
    state = state.copyWith(busy: true, error: MembershipError.none);
    try {
      final String token = await _freshAccessToken();
      final PayfastCheckout checkout = await _api.checkout(token);
      final bool opened = await launchUrl(
        checkout.launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        state = state.copyWith(busy: false, error: MembershipError.openFailed);
        return;
      }
      state = state.copyWith(busy: false, awaitingPayment: true);
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } on MembershipApiException catch (error) {
      if (error.isUnauthorised) {
        await signOut();
        return;
      }
      if (error.isPasswordChangeRequired) {
        state = state.copyWith(
          phase: AuthPhase.mustChangePassword,
          busy: false,
        );
        return;
      }
      state = state.copyWith(
        busy: false,
        error: error.statusCode == 409
            ? MembershipError.alreadySubscribed
            : MembershipError.checkoutFailed,
      );
    } on _SignedOut {
      // Already handled.
    } catch (_) {
      state = state.copyWith(busy: false, error: MembershipError.openFailed);
    }
  }

  /// "Cancel subscription": first tap asks for confirmation, second cancels.
  /// Access is kept until the paid month ends — the server says until when.
  Future<void> cancelSubscription() async {
    if (kStoreBuild || _session == null || state.busy) {
      return;
    }
    if (!state.confirmingCancel) {
      state = state.copyWith(
        confirmingCancel: true,
        error: MembershipError.none,
      );
      return;
    }
    state = state.copyWith(busy: true, error: MembershipError.none);
    try {
      final String token = await _freshAccessToken();
      final (Entitlement entitlement, Map<String, dynamic> raw) =
          await _api.cancel(token);
      await _prefs.saveCachedEntitlementJson(
        jsonEncode(entitlement.toCacheJson(raw)),
      );
      _applyEntitlement(entitlement, fromCache: false);
      state = state.copyWith(confirmingCancel: false, cancelledNotice: true);
    } on MembershipOffline {
      state = state.copyWith(
        busy: false,
        confirmingCancel: false,
        error: MembershipError.offline,
      );
    } on MembershipApiException catch (error) {
      if (error.isUnauthorised) {
        await signOut();
        return;
      }
      state = state.copyWith(
        busy: false,
        confirmingCancel: false,
        error: MembershipError.cancelFailed,
      );
    } on _SignedOut {
      // Already handled.
    }
  }

  /// Clears an inline error / notice.
  void dismissError() {
    state = state.copyWith(
      error: MembershipError.none,
      cancelledNotice: false,
      recoverySent: false,
      confirmationResent: false,
      passwordChanged: false,
    );
  }

  // ------------------------------------------------------------- internals

  /// A usable access token for the centres download, or `null` when there is
  /// no session (or the device is offline and the token needs refreshing).
  Future<String?> currentAccessToken() async {
    if (_session == null) {
      return null;
    }
    try {
      return await _freshAccessToken();
    } on _SignedOut {
      return null;
    } on MembershipOffline {
      return null;
    } on MembershipApiException {
      return null;
    }
  }

  String get _trialIntroKey {
    final String? id = _session?.userId;
    return (id != null && id.isNotEmpty) ? id : state.email;
  }

  Future<void> _adoptSession(AuthSession session) async {
    _session = session;
    await _sessions.write(session);
    state = state.copyWith(
      email: session.email.isNotEmpty ? session.email : state.email,
    );
  }

  /// Returns a usable access token, refreshing when it is about to expire.
  /// On a 4xx refresh failure the user is signed out locally; a network
  /// failure throws [MembershipOffline] and changes nothing.
  Future<String> _freshAccessToken() async {
    final AuthSession? session = _session;
    if (session == null) {
      throw const _SignedOut();
    }
    if (!session.isExpiring()) {
      return session.accessToken;
    }
    try {
      final AuthSession refreshed = await _auth.refresh(session);
      _session = refreshed;
      await _sessions.write(refreshed);
      return refreshed.accessToken;
    } on MembershipApiException catch (error) {
      if (error.statusCode >= 400 && error.statusCode < 500) {
        await signOut();
        throw const _SignedOut();
      }
      rethrow;
    }
  }

  static MembershipError _authError(AuthErrorKind kind) => switch (kind) {
        AuthErrorKind.invalidCredentials => MembershipError.invalidCredentials,
        AuthErrorKind.emailNotConfirmed => MembershipError.emailNotConfirmed,
        AuthErrorKind.alreadyRegistered => MembershipError.alreadyRegistered,
        AuthErrorKind.weakPassword => MembershipError.weakPassword,
        AuthErrorKind.rateLimited => MembershipError.rateLimited,
        AuthErrorKind.offline => MembershipError.offline,
        AuthErrorKind.server || AuthErrorKind.unknown => MembershipError.authFailed,
      };
}

class _SignedOut implements Exception {
  const _SignedOut();
}

final Provider<SupabaseAuthClient> supabaseAuthClientProvider =
    Provider<SupabaseAuthClient>((ref) => SupabaseAuthClient());

final Provider<MembershipApiClient> membershipApiClientProvider =
    Provider<MembershipApiClient>((ref) => MembershipApiClient());

final Provider<SessionStore> sessionStoreProvider =
    Provider<SessionStore>((ref) => const SecureSessionStore());

final NotifierProvider<MembershipController, MembershipState>
    membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
  MembershipController.new,
);
