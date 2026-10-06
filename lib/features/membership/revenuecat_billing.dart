import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../core/config/app_config.dart';

/// RevenueCat bridge for store builds. RevenueCat identifies and processes
/// store transactions; `/api/me` remains the authority for app access.
class RevenueCatBilling {
  Future<void> identify(String userId) async {
    if (userId.isEmpty) {
      throw StateError('A Supabase user id is required for store billing.');
    }
    if (kRevenueCatApiKey.isEmpty) {
      throw StateError(
        'Set REVENUECAT_API_KEY to the public SDK key for this store app.',
      );
    }

    if (!await Purchases.isConfigured) {
      await Purchases.configure(
        PurchasesConfiguration(kRevenueCatApiKey)..appUserID = userId,
      );
      return;
    }

    if (await Purchases.appUserID != userId) {
      await Purchases.logIn(userId);
    }
  }

  /// Displays the current RevenueCat offering/paywall configured in the
  /// dashboard. Products and localized prices are loaded from the stores.
  Future<PaywallResult> presentPaywall(String userId) async {
    await identify(userId);
    return RevenueCatUI.presentPaywall();
  }

  /// Restores transactions for the active store account. This does not itself
  /// grant access; callers must refresh the membership API afterwards.
  Future<bool> restorePurchases(String userId) async {
    await identify(userId);
    final CustomerInfo info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(kRevenueCatEntitlementId);
  }

  /// Opens RevenueCat's native subscription management and restore UI.
  Future<bool> presentCustomerCenter(String userId) async {
    await identify(userId);
    await RevenueCatUI.presentCustomerCenter();
    final CustomerInfo info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(kRevenueCatEntitlementId);
  }

  Future<void> logOut() async {
    if (!await Purchases.isConfigured || await Purchases.isAnonymous) {
      return;
    }
    await Purchases.logOut();
  }
}
