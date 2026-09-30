/// Build-time flags and service endpoints.
///
/// Everything here is a compile-time constant so that dead code (for example
/// the whole membership feature when [kMembershipEnabled] is `false`) is
/// tree-shaken out of release builds. Override with `--dart-define`, e.g.
///
/// ```bash
/// flutter build appbundle --dart-define=MEMBERSHIP_ENABLED=true \
///     --dart-define=STORE_BUILD=true
/// ```
library;

/// Whether the optional membership feature (sign-in, trial, PayFast
/// subscription) is compiled in. Off by default: the compass, the sun, the
/// centres and the guide never depend on it.
const bool kMembershipEnabled =
    bool.fromEnvironment('MEMBERSHIP_ENABLED', defaultValue: false);

/// Store builds (Google Play / App Store) hide every purchase or subscribe
/// control and keep only sign-in and the membership status, to stay within the
/// stores' in-app purchase rules.
const bool kStoreBuild = bool.fromEnvironment('STORE_BUILD', defaultValue: false);

/// Membership API (the Vercel deployment of the web edition). Placeholder.
const String kMembershipApiBaseUrl = String.fromEnvironment(
  'MEMBERSHIP_API_BASE_URL',
  defaultValue: 'https://example.invalid',
);

/// Supabase project URL used for e-mail one-time-code sign-in. Placeholder.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://your-project.supabase.co',
);

/// Supabase anonymous (public) API key. Placeholder — it is safe to ship the
/// real anon key in the app; it is not a secret.
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_SUPABASE_ANON_KEY',
);

/// Soft cap of the on-disk map tile cache (about 50 MB). Ignored (cache off)
/// in the low performance profile.
const int kTileCacheMaxBytes = 50 * 1000 * 1000;

/// Application id / bundle id, also used as the OpenStreetMap user agent.
const String kApplicationId = 'com.tshk.tshk_compass';
