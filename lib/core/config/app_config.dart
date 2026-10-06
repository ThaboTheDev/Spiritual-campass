/// Build-time flags and service endpoints.
///
/// Everything here is a compile-time constant so that dead code (for example
/// the purchase controls when [kStoreBuild] is `true`) is tree-shaken out of
/// release builds. Override with `--dart-define`, e.g.
///
/// ```bash
/// flutter build appbundle \
///     --dart-define=MEMBERSHIP_API_BASE_URL=https://members.example.org \
///     --dart-define=SUPABASE_URL=https://abcd.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// Membership is no longer optional: the whole app (the compass included) is
/// behind e-mail + password login and behind access (trial or paid), so these
/// three values must be supplied for any build that is meant to run.
///
/// The app uses neither e-mail confirmation nor password recovery, so there is
/// no site URL to redirect a browser to.
library;

/// Store builds (Google Play / App Store) use RevenueCat for purchases and
/// subscription management instead of the web PayFast flow.
const bool kStoreBuild = bool.fromEnvironment(
  'STORE_BUILD',
  defaultValue: false,
);

/// RevenueCat public SDK key. Supply a platform-specific key at build time;
/// public SDK keys are safe to ship, but private RevenueCat secret keys are not.
const String kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: '',
);

/// RevenueCat entitlement unlocked by any configured membership product.
const String kRevenueCatEntitlementId = String.fromEnvironment(
  'REVENUECAT_ENTITLEMENT_ID',
  defaultValue: 'test_pro',
);

/// Our own API (the Vercel deployment of the web edition): `/api/me`,
/// `/api/centres`, `/api/account/password`, `/api/payfast/*`, `/api/admin/*`.
/// Placeholder — supply the real one with `--dart-define`.
const String kMembershipApiBaseUrl = String.fromEnvironment(
  'MEMBERSHIP_API_BASE_URL',
  defaultValue: 'https://example.invalid',
);

/// Supabase project URL used for e-mail + password authentication (the Auth
/// REST endpoints, no SDK). Placeholder.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://your-project.supabase.co',
);

/// Supabase anonymous (public) API key. Placeholder — it is safe to ship the
/// real anon key in the app; it is not a secret.
///
/// The project must have **Confirm email** switched off (Authentication ▸
/// Providers ▸ Email): the app signs a new member in straight after sign-up
/// and has no confirmation step.
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_SUPABASE_ANON_KEY',
);

/// Soft cap of the on-disk map tile cache (about 50 MB). Ignored (cache off)
/// in the low performance profile.
const int kTileCacheMaxBytes = 50 * 1000 * 1000;

/// Application id / bundle id, also used as the OpenStreetMap user agent.
const String kApplicationId = 'com.tshk.tshk_compass';
