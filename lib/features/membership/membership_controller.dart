import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_providers.dart';
import '../../core/config/app_config.dart';
import '../../data/local/preferences_store.dart';
import 'membership_api.dart';
import 'membership_models.dart';
import 'session_store.dart';

/// Where the membership UI is.
enum MembershipPhase {
  /// Feature flag off, or nothing loaded yet.
  idle,

  /// Not signed in: e-mail entry.
  signedOut,

  /// Code sent: 6-digit entry.
  codeSent,

  /// Signed in, talking to `/api/me`.
  checking,

  /// Signed in with a (fresh or cached) entitlement.
  ready,

  /// Signed in but offline with no usable cache.
  offline,
}

/// Errors shown inline, mapped to strings by the widget.
enum MembershipError {
  none,
  badEmail,
  sendFailed,
  badCode,
  wrongCode,
  offline,
  checkoutFailed,
  alreadySubscribed,
  cancelFailed,
  openFailed,
}

class MembershipState {
  const MembershipState({
    this.phase = MembershipPhase.idle,
    this.email = '',
    this.entitlement,
    this.fromCache = false,
    this.busy = false,
    this.error = MembershipError.none,
    this.confirmingCancel = false,
    this.awaitingPayment = false,
    this.cancelledNotice = false,
  });

  final MembershipPhase phase;
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

  bool get isSignedIn =>
      phase == MembershipPhase.checking ||
      phase == MembershipPhase.ready ||
      phase == MembershipPhase.offline;

  /// Whether the member currently has access (server or valid cache).
  bool get hasAccess {
    final Entitlement? e = entitlement;
    if (e == null) {
      return false;
    }
    return fromCache ? e.cachedAccessValid() : e.access;
  }

  MembershipState copyWith({
    MembershipPhase? phase,
    String? email,
    Entitlement? entitlement,
    bool clearEntitlement = false,
    bool? fromCache,
    bool? busy,
    MembershipError? error,
    bool? confirmingCancel,
    bool? awaitingPayment,
    bool? cancelledNotice,
  }) {
    return MembershipState(
      phase: phase ?? this.phase,
      email: email ?? this.email,
      entitlement: clearEntitlement ? null : (entitlement ?? this.entitlement),
      fromCache: fromCache ?? this.fromCache,
      busy: busy ?? this.busy,
      error: error ?? this.error,
      confirmingCancel: confirmingCancel ?? this.confirmingCancel,
      awaitingPayment: awaitingPayment ?? this.awaitingPayment,
      cancelledNotice: cancelledNotice ?? this.cancelledNotice,
    );
  }
}

/// Supabase OTP sign-in, `/api/me`, PayFast checkout / cancel, and the
/// offline entitlement cache. Does nothing when [kMembershipEnabled] is off.
class MembershipController extends Notifier<MembershipState> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  SupabaseAuthClient get _auth => ref.read(supabaseAuthClientProvider);
  MembershipApiClient get _api => ref.read(membershipApiClientProvider);
  SessionStore get _sessions => ref.read(sessionStoreProvider);
  PreferencesStore get _prefs => ref.read(preferencesStoreProvider);

  AuthSession? _session;

  @override
  MembershipState build() {
    if (!kMembershipEnabled) {
      return const MembershipState();
    }
    Future<void>.microtask(_restore);
    return const MembershipState(phase: MembershipPhase.signedOut, busy: true);
  }

  // -------------------------------------------------------------- sign-in

  /// Sends the OTP e-mail.
  Future<void> sendCode(String email) async {
    final String trimmed = email.trim();
    if (!_emailPattern.hasMatch(trimmed)) {
      state = state.copyWith(error: MembershipError.badEmail);
      return;
    }
    state = state.copyWith(busy: true, error: MembershipError.none, email: trimmed);
    try {
      await _auth.sendCode(trimmed);
      state = state.copyWith(phase: MembershipPhase.codeSent, busy: false);
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } catch (_) {
      state = state.copyWith(busy: false, error: MembershipError.sendFailed);
    }
  }

  /// Verifies the 6-digit code and stores the session securely.
  Future<void> verifyCode(String code) async {
    final String token = code.trim();
    if (token.length < 6) {
      state = state.copyWith(error: MembershipError.badCode);
      return;
    }
    state = state.copyWith(busy: true, error: MembershipError.none);
    try {
      final AuthSession session = await _auth.verifyCode(state.email, token);
      _session = session;
      await _sessions.write(session);
      state = state.copyWith(
        phase: MembershipPhase.checking,
        email: session.email,
        busy: false,
      );
      await refreshEntitlement();
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: MembershipError.offline);
    } catch (_) {
      state = state.copyWith(busy: false, error: MembershipError.wrongCode);
    }
  }

  /// Back to the e-mail field.
  void changeEmail() {
    state = state.copyWith(
      phase: MembershipPhase.signedOut,
      error: MembershipError.none,
    );
  }

  /// Signs out locally and drops the cached entitlement.
  Future<void> signOut() async {
    _session = null;
    await _sessions.clear();
    await _prefs.saveCachedEntitlementJson(null);
    state = const MembershipState(phase: MembershipPhase.signedOut);
  }

  // ---------------------------------------------------------- entitlement

  /// `GET /api/me`; falls back to the cached entitlement while offline.
  Future<void> refreshEntitlement({bool afterPayment = false}) async {
    if (_session == null) {
      return;
    }
    state = state.copyWith(
      busy: true,
      error: MembershipError.none,
      awaitingPayment: afterPayment,
      confirmingCancel: false,
    );
    try {
      final String token = await _freshAccessToken();
      final (Entitlement entitlement, Map<String, dynamic> raw) =
          await _api.me(token);
      await _prefs.saveCachedEntitlementJson(
        jsonEncode(entitlement.toCacheJson(raw)),
      );
      state = state.copyWith(
        phase: MembershipPhase.ready,
        entitlement: entitlement,
        fromCache: false,
        busy: false,
        awaitingPayment: afterPayment && !entitlement.access,
      );
    } on MembershipOffline {
      _useCache();
    } on MembershipApiException catch (error) {
      if (error.isAuthError) {
        await signOut();
        return;
      }
      _useCache(error: MembershipError.offline);
    } on _SignedOut {
      // Refresh token rejected: already signed out.
    }
  }

  void _useCache({MembershipError error = MembershipError.none}) {
    final Entitlement? cached = _readCache();
    if (cached != null) {
      state = state.copyWith(
        phase: MembershipPhase.ready,
        entitlement: cached,
        fromCache: true,
        busy: false,
        error: error,
      );
    } else {
      state = state.copyWith(
        phase: MembershipPhase.offline,
        busy: false,
        error: MembershipError.offline,
      );
    }
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

  // -------------------------------------------------------------- PayFast

  /// Opens the signed PayFast checkout in the external browser. Hidden in
  /// store builds; guarded here as well.
  Future<void> startCheckout() async {
    if (kStoreBuild || _session == null) {
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
      if (error.isAuthError) {
        await signOut();
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
  Future<void> cancelSubscription() async {
    if (kStoreBuild || _session == null) {
      return;
    }
    if (!state.confirmingCancel) {
      state = state.copyWith(confirmingCancel: true, error: MembershipError.none);
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
      state = state.copyWith(
        entitlement: entitlement,
        fromCache: false,
        busy: false,
        confirmingCancel: false,
        cancelledNotice: true,
      );
    } on MembershipOffline {
      state = state.copyWith(
        busy: false,
        confirmingCancel: false,
        error: MembershipError.offline,
      );
    } on MembershipApiException catch (error) {
      if (error.isAuthError) {
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
    state = state.copyWith(error: MembershipError.none, cancelledNotice: false);
  }

  // ------------------------------------------------------------- internals

  Future<void> _restore() async {
    final AuthSession? session = await _sessions.read();
    if (session == null) {
      state = const MembershipState(phase: MembershipPhase.signedOut);
      return;
    }
    _session = session;
    state = MembershipState(
      phase: MembershipPhase.checking,
      email: session.email,
      busy: true,
    );
    await refreshEntitlement();
  }

  /// Returns a usable access token, refreshing when it is about to expire.
  /// On a 4xx refresh failure the user is signed out locally.
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
