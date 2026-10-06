# RevenueCat store billing: app and backend setup

This Flutter app now has RevenueCat SDK/UI integration for store builds. The
membership API is intentionally still authoritative: a successful store
purchase or an active RevenueCat SDK entitlement **does not by itself unlock
the app**. `/api/me` must grant access after the backend has verified the
RevenueCat event.

## 1. RevenueCat dashboard and store products

1. Create a RevenueCat project and add the Android application and iOS app with
   the exact package/bundle identifiers used by this app.
2. Connect the Google Play service account and App Store Connect in RevenueCat.
   Complete each store's subscription and in-app-purchase setup, including
   agreements, tax/banking details, signing, and sandbox/license testers.
3. Create store products. `lifetime`, `yearly`, and `monthly` in the request
   are proposed product IDs, not guaranteed IDs: confirm the exact product IDs
   created in each store. Configure:
   - Lifetime: non-consumable / one-time purchase.
   - Yearly: auto-renewing annual subscription.
   - Monthly: auto-renewing monthly subscription.
   Use matching product IDs on both stores where possible.
4. Create the entitlement **`test_pro`** (or choose another stable ID and set
   `REVENUECAT_ENTITLEMENT_ID` to that exact value). Attach all three products
   to that entitlement. The app checks this ID for customer status.
5. Create a current Offering (for example `default`), add the lifetime,
   yearly, and monthly packages/products, then create and publish a RevenueCat
   Paywall for that offering. Set localized prices and clear renewal/one-time
   purchase terms in the Paywall Editor. Ensure the offering is available to
   all store customers or matches your intended targeting.
6. Configure Customer Center in RevenueCat (support contact, cancellation
   guidance, restore, refund actions where supported). Customer Center is
   available only on eligible RevenueCat plans.
7. Use the `test_...` RevenueCat API key only with the RevenueCat Test Store.
   For Google Play and App Store sandbox/production builds, use the **public
   platform-specific SDK key** from the RevenueCat project, never a secret
   API key. SDK public keys are client-visible; RevenueCat secret keys and
   webhook authorization secrets must remain server-side.

## 2. Build and run the Flutter store flow

Installations are already in `pubspec.yaml` (`purchases_flutter` and
`purchases_ui_flutter`). The Android `MainActivity` is now a
`FlutterFragmentActivity` as required by RevenueCat Paywalls; its
`singleTop` launch mode and the iOS 13 deployment target satisfy the SDK
requirements.

Supply the test key for RevenueCat Test Store (or the matching public
platform-specific SDK key for store testing/release) when building:

```bash
flutter run \
  --dart-define=STORE_BUILD=true \
  --dart-define=REVENUECAT_API_KEY=test_MQnnvdyzVqodxRcFvJBNOnYKWsu \
  --dart-define=REVENUECAT_ENTITLEMENT_ID=test_pro \
  --dart-define=MEMBERSHIP_API_BASE_URL=https://<your-api> \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-public-anon-key>
```

Use the same defines with `flutter build appbundle` / `flutter build ipa` for
store artifacts, replacing the test key with each store's public SDK key. Keep
these build arguments out of checked-in files if they contain deployment
configuration. The SDK key itself is public; Supabase anon key is also public,
but neither should be mistaken for backend credentials.

`STORE_BUILD=true` shows RevenueCat's configured paywall on the trial and
expired-membership screens, and exposes Restore purchases and Customer Center
from the account screen. Direct/sideload builds keep PayFast instead. The app
uses the logged-in Supabase user ID as RevenueCat's App User ID so that webhook
events can be associated with the same member. Sign-out logs out of RevenueCat.

## 3. Backend/API changes required

These changes belong in the separately deployed Vercel membership API; they
cannot be completed from this Flutter repository:

### Secure RevenueCat webhook

- Configure a RevenueCat webhook URL, e.g. `POST /api/webhooks/revenuecat`,
  protected by a long random authorization value stored only as a server
  environment secret. Compare the authorization header securely; never put
  the secret in Flutter or expose it in logs.
- Parse RevenueCat event payloads, including the event ID, event type, App User
  ID, product ID, entitlement IDs, store, transaction/original transaction
  IDs, expiration, cancellation/refund fields, and event timestamp.
- Require `app_user_id` to be a valid existing Supabase user ID. The app
  explicitly logs RevenueCat in with that ID. Do not associate purchases by
  untrusted email, product ID, or client-submitted entitlement claims.
- Verify the webhook authorization and validate the event shape before writes.
  Acknowledge valid duplicate deliveries idempotently; persist event IDs with a
  unique constraint and transactionally upsert the entitlement. Return a
  successful response for already-processed events.
- Handle purchase/initial purchase, renewal, product change, cancellation,
  expiration, billing issue/grace, uncancellation, refund, and transfer events.
  Map RevenueCat event types and expiration timestamps carefully; a cancellation
  generally stops renewal but does **not** remove access before expiration.
- Persist enough source details for reconciliation: Supabase user ID,
  RevenueCat App User ID, product/entitlement, store, transaction IDs, status,
  purchase time, paid-through/expiration, cancellation time, and last processed
  event. Keep webhook payloads only as long as needed and redact personal data.
- Decide and implement the transfer policy. RevenueCat may emit transfer events
  if a store purchase moves between App User IDs. Do not silently grant the
  same purchase to multiple accounts; define how to handle transfers and
  restore conflicts and reconcile affected users.

### `/api/me` and access rules

- Preserve the existing response shape and compute `access` on the server from
  the combined entitlement sources: trial, PayFast, and RevenueCat. Continue
  serving active access through the store's paid-through date after
  auto-renew cancellation; end access on expiration/refund according to the
  event data.
- Add explicit source/product metadata only if the Flutter parser is updated
  defensively; useful fields include `billing_source` (`payfast` or
  `app_store`/`play_store`), `product_id`, and `current_period_end`. Do not
  return store receipt credentials or RevenueCat secret credentials.
- Keep webhooks authoritative and `/api/me` fast. Do not call a RevenueCat
  secret API on every app request unless using it as a deliberate, cached
  reconciliation fallback.
- If retaining the seven-day trial, define whether it applies across all
  billing sources and make it one-time per Supabase account. Do not also grant
  unplanned store free trials; configure any introductory offers in the stores
  and account for them explicitly.
- Reconcile existing PayFast cancellation, membership deletion, and admin
  account actions with store billing. The current `/api/payfast/cancel` must
  remain PayFast-only; Customer Center handles store subscription changes.
  Deleting a member must not imply a store refund; document whether the
  subscription remains in the store and how its App User ID/access is handled.

### Operations and tests

- Configure RevenueCat webhook delivery/retries and monitor failed or
  repeatedly delayed events. Add a periodic reconciliation job against
  RevenueCat's server-side API if appropriate; hold its secret key only in the
  API environment.
- Add backend tests for webhook auth failures, malformed payloads, duplicate
  events, unknown users, each lifecycle event, out-of-order events, transfers,
  refunded lifetime purchases, renewal/expiration, and overlapping PayFast +
  store access.
- Test purchase, cancellation, restore, and renewal with Apple sandbox,
  Google Play license testers, and RevenueCat Test Store as separate flows.
  Verify that `/api/me` changes only after server-side processing, including
  delayed webhook delivery and offline/relaunch cases.
- Add alerts and a support/reconciliation process for payments whose store
  transaction is active while the membership API has not yet processed the
  corresponding event.

## Security and behavior notes

- The Flutter `test_pro` check controls paywall presentation and restore
  messaging only. The app deliberately refreshes `/api/me` after purchase and
  restore; it never changes local membership access based on `CustomerInfo`.
- Do not log access tokens, webhook authorization values, receipts, raw
  transaction data, or complete customer information.
- Restore purchases may discover a purchase attached to a different app user.
  The backend must enforce the chosen account-transfer policy before it grants
  membership.
- Keep RevenueCat, App Store, and Play product setup consistent. A product
  missing from the active RevenueCat offering cannot be purchased through the
  hosted paywall.

