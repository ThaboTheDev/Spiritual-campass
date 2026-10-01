import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../centres/centres_providers.dart';
import '../membership_api.dart';
import '../membership_controller.dart';
import '../membership_models.dart';

/// What went wrong in the admin area, in terms the UI can explain.
enum AdminError {
  none,
  forbidden,
  offline,
  failed,
  duplicateCentre,
  invalidCentre,
  cannotDeleteSelf,
  payfastCancelFailed,
}

/// State of the three admin tools.
///
/// Note what is **not** here: the generated temporary password. It is
/// returned straight to the caller, lives in the dialog's widget state and
/// is gone the moment the dialog closes.
class AdminState {
  const AdminState({
    this.busy = false,
    this.error = AdminError.none,
    this.users = const <AdminUser>[],
    this.searched = false,
    this.selected,
    this.invalidFields = const <String>[],
    this.addedCentre,
    this.deletedEmail,
    this.deletedSubscriptionCancelled = false,
  });

  final bool busy;
  final AdminError error;

  /// Result of the last `GET /api/admin/users`.
  final List<AdminUser> users;

  /// Whether a search has been run at all (so "no matches" only shows after).
  final bool searched;

  /// The user the admin picked.
  final AdminUser? selected;

  /// Fields the server rejected on `POST /api/admin/centres`.
  final List<String> invalidFields;

  /// Name of the centre just added, for the confirmation message.
  final String? addedCentre;

  /// E-mail of the user just deleted.
  final String? deletedEmail;

  /// Whether that user's PayFast subscription was cancelled too.
  final bool deletedSubscriptionCancelled;

  AdminState copyWith({
    bool? busy,
    AdminError? error,
    List<AdminUser>? users,
    bool? searched,
    AdminUser? selected,
    bool clearSelected = false,
    List<String>? invalidFields,
    String? addedCentre,
    bool clearAddedCentre = false,
    String? deletedEmail,
    bool clearDeleted = false,
    bool? deletedSubscriptionCancelled,
  }) =>
      AdminState(
        busy: busy ?? this.busy,
        error: error ?? this.error,
        users: users ?? this.users,
        searched: searched ?? this.searched,
        selected: clearSelected ? null : selected ?? this.selected,
        invalidFields: invalidFields ?? this.invalidFields,
        addedCentre:
            clearAddedCentre ? null : addedCentre ?? this.addedCentre,
        deletedEmail: clearDeleted ? null : deletedEmail ?? this.deletedEmail,
        deletedSubscriptionCancelled: clearDeleted
            ? false
            : deletedSubscriptionCancelled ??
                this.deletedSubscriptionCancelled,
      );
}

/// The three admin tools: add a centre, auto-generate a password, delete a
/// user. Every call is also checked by the server (`403 admin_required`).
class AdminController extends Notifier<AdminState> {
  MembershipApiClient get _api => ref.read(membershipApiClientProvider);
  MembershipController get _membership =>
      ref.read(membershipControllerProvider.notifier);

  @override
  AdminState build() => const AdminState();

  /// `GET /api/admin/users?q=…`.
  Future<void> searchUsers(String query) async {
    if (state.busy) {
      return;
    }
    state = state.copyWith(
      busy: true,
      error: AdminError.none,
      clearSelected: true,
    );
    final String? token = await _membership.currentAccessToken();
    if (token == null) {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return;
    }
    try {
      final List<AdminUser> users = await _api.adminUsers(token, query.trim());
      state = state.copyWith(busy: false, users: users, searched: true);
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: AdminError.offline);
    } on MembershipApiException catch (error) {
      state = state.copyWith(busy: false, error: _map(error));
    }
  }

  /// Picks a user for the password / delete tools.
  void select(AdminUser? user) {
    state = state.copyWith(
      selected: user,
      clearSelected: user == null,
      error: AdminError.none,
      clearDeleted: true,
    );
  }

  /// `POST /api/admin/centres`; refreshes the centres list on success so the
  /// new centre shows at once.
  Future<bool> addCentre({
    required String region,
    required String name,
    required String address,
    required String phone,
    required double lat,
    required double lng,
  }) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(
      busy: true,
      error: AdminError.none,
      invalidFields: const <String>[],
      clearAddedCentre: true,
    );
    final String? token = await _membership.currentAccessToken();
    if (token == null) {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return false;
    }
    try {
      await _api.adminAddCentre(
        token,
        region: region,
        name: name,
        address: address,
        phone: phone,
        lat: lat,
        lng: lng,
      );
      await ref.read(centresProvider.notifier).refresh();
      state = state.copyWith(busy: false, addedCentre: name);
      return true;
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return false;
    } on MembershipApiException catch (error) {
      state = state.copyWith(
        busy: false,
        error: _map(error),
        invalidFields: error.fields,
      );
      return false;
    }
  }

  /// `POST /api/admin/users/reset-password`.
  ///
  /// The password is **returned**, never stored in this state, never logged
  /// and never persisted: the dialog shows it once and then forgets it.
  Future<TemporaryPassword?> generateTemporaryPassword() async {
    final AdminUser? user = state.selected;
    if (user == null || state.busy) {
      return null;
    }
    state = state.copyWith(busy: true, error: AdminError.none);
    final String? token = await _membership.currentAccessToken();
    if (token == null) {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return null;
    }
    try {
      final TemporaryPassword result =
          await _api.adminResetPassword(token, user.userId);
      state = state.copyWith(busy: false);
      return result;
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return null;
    } on MembershipApiException catch (error) {
      state = state.copyWith(busy: false, error: _map(error));
      return null;
    }
  }

  /// `POST /api/admin/users/delete`.
  Future<bool> deleteSelectedUser() async {
    final AdminUser? user = state.selected;
    if (user == null || state.busy) {
      return false;
    }
    state = state.copyWith(
      busy: true,
      error: AdminError.none,
      clearDeleted: true,
    );
    final String? token = await _membership.currentAccessToken();
    if (token == null) {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return false;
    }
    try {
      final DeleteUserResult result =
          await _api.adminDeleteUser(token, user.userId);
      state = state.copyWith(
        busy: false,
        deletedEmail: user.email,
        deletedSubscriptionCancelled: result.subscriptionCancelled,
        users: state.users
            .where((AdminUser u) => u.userId != user.userId)
            .toList(growable: false),
        clearSelected: true,
      );
      return true;
    } on MembershipOffline {
      state = state.copyWith(busy: false, error: AdminError.offline);
      return false;
    } on MembershipApiException catch (error) {
      // payfast_cancel_failed means nothing was deleted: stop and say so.
      state = state.copyWith(busy: false, error: _map(error));
      return false;
    }
  }

  /// Clears the inline error / confirmation messages.
  void dismiss() {
    state = state.copyWith(
      error: AdminError.none,
      clearAddedCentre: true,
      clearDeleted: true,
      invalidFields: const <String>[],
    );
  }

  static AdminError _map(MembershipApiException error) {
    if (error.isAdminRequired) {
      return AdminError.forbidden;
    }
    switch (error.code) {
      case 'duplicate_centre':
        return AdminError.duplicateCentre;
      case 'invalid_centre':
        return AdminError.invalidCentre;
      case 'cannot_delete_self':
        return AdminError.cannotDeleteSelf;
      case 'payfast_cancel_failed':
        return AdminError.payfastCancelFailed;
      default:
        return AdminError.failed;
    }
  }
}

final NotifierProvider<AdminController, AdminState> adminControllerProvider =
    NotifierProvider<AdminController, AdminState>(AdminController.new);
