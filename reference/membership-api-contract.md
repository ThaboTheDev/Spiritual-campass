# Membership API contract (from the web edition). Optional feature.

Base URL: configurable constant (the Vercel deployment). All calls except Supabase auth need
`Authorization: Bearer <supabase access_token>`.

## Sign-in (Supabase Auth REST, no SDK needed). Header on every call: `apikey: <SUPABASE_ANON_KEY>`
- Send code:  POST {SUPABASE_URL}/auth/v1/otp        body {"email": e, "create_user": true}
- Verify:     POST {SUPABASE_URL}/auth/v1/verify     body {"type":"email","email": e,"token":"123456"}
              -> {access_token, refresh_token, expires_in, user:{email}}
- Refresh:    POST {SUPABASE_URL}/auth/v1/token?grant_type=refresh_token  body {"refresh_token": r}
              On a 4xx refresh error, sign the user out locally.
Session stored locally: access_token, refresh_token, expires_at (= now + expires_in*1000), email.
Store it with flutter_secure_storage.

## GET /api/me
Creates the member row on first call and starts the 7-day trial. 200 body:
{ email, status, ...entitlement, can_cancel, price, currency:"ZAR", trial_days }
`entitlement` contributes the fields that say whether access is allowed (`access` boolean plus a
`state` such as trial / active / grace / expired / cancelled and the relevant end date).
Read the body defensively: log unknown fields, never crash on missing ones.

## GET /api/centres
200 { regions: [...], centres: [{r,n,a,p,la,lo}] }   402 { error: "subscription_required" } when no access.

## POST /api/payfast/checkout
200 -> a signed PayFast form description (action URL + fields). Open PayFast checkout in the EXTERNAL browser
(url_launcher). 409 { error: "already_subscribed" }.
After returning to the app, call /api/me again (payment confirmation arrives server-side via PayFast ITN).

## POST /api/payfast/cancel
200 { ok: true, ...entitlement }   400 { error: "no_active_subscription" }   502 { error: "payfast_cancel_failed" }

## Access rules to mirror (server decides; app only displays)
- 7-day free trial, then R100/month via PayFast; short grace period after a missed payment.
- Cancelled subscriptions keep access until the paid-through date.
- Cache the last confirmed entitlement locally so it works offline until that date; never treat the cache as authoritative when online.
- Store builds (kStoreBuild = true): hide every purchase/subscribe control, keep sign-in and status only.
