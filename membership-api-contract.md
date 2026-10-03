# Membership API contract. Mandatory: the whole app is behind it.

Base URL: `MEMBERSHIP_API_BASE_URL` (`--dart-define`). Every call except the
Supabase auth ones needs `Authorization: Bearer <supabase access_token>`.

Nothing here may be renamed: the backend is built to exactly these names.

## Sign-in (Supabase Auth REST, no SDK). Header on every call: `apikey: <SUPABASE_ANON_KEY>`

E-mail confirmation and password recovery are **not** used. The Supabase
project must have *Confirm email* switched off, so a sign-up answers with a
session and the member is signed in immediately. A forgotten password is issued
by an administrator (`POST /api/admin/users/reset-password`), which sets
`must_change_password` and forces the change-password screen at the next login.

- Sign up:    POST {SUPABASE_URL}/auth/v1/signup   body {"email": e, "password": p}
              -> {access_token, refresh_token, expires_in, user:{id, email}}
- Log in:     POST {SUPABASE_URL}/auth/v1/token?grant_type=password
              body {"email": e, "password": p}
              -> {access_token, refresh_token, expires_in, user:{id, email}}
- Refresh:    POST {SUPABASE_URL}/auth/v1/token?grant_type=refresh_token
              body {"refresh_token": r}
              On a **4xx** refresh error, sign the user out locally. A network
              failure must change nothing.

Session stored locally: access_token, refresh_token, expires_at
(= now + expires_in*1000), email, user_id — in `flutter_secure_storage`.

Error bodies are read from `error_code` / `code` / `error` and
`msg` / `message` / `error_description`, and mapped to:
`invalid_credentials` (incl. `invalid_grant`), `user_already_exists` /
`email_exists`, `weak_password`, rate limited (429), server (5xx), unknown.

## GET /api/me

Creates the member row on the first call and starts the 7-day trial. 200 body:

```
{ email, status, state, access, can_cancel, price, currency:"ZAR", trial_days,
  ends_at | paid_through | access_until | current_period_end | trial_ends_at |
  grace_until | expires_at,
  is_admin, must_change_password }
```

* `state`: trial / active / grace (past_due) / expired / cancelled — anything
  else is shown as text, never crashes.
* `is_admin: true` reveals the admin area in the app. The server must still
  check it on every admin call.
* `must_change_password: true` means an administrator generated a password:
  the app shows the forced change screen and nothing else.

Read the body defensively: log unknown fields, never crash on missing ones.

**403 `{"error":"password_change_required"}`** may come back from *any*
`/api/*` call while `must_change_password` is set. It means "go to the
change-password screen" — it is **never** a reason to sign out. Only 401 is.

## POST /api/account/password

body `{"new_password": p}` → 200 `{ok:true}`.
400 `{"error":"weak_password"}` when the password is too short/weak.
The app logs in again with the new password straight afterwards, because the
change may revoke the old session.

## GET /api/centres

200 `{ regions: [...], centres: [{id, r, n, a, p, la, lo}] }`
402 `{ error: "subscription_required" }` when there is no access
(401 when the session is invalid).

The list is **not** bundled with the app: it is downloaded after login and
cached in app-private storage for offline use, and dropped on 401 / 402 / log
out.

## POST /api/payfast/checkout

200 → a signed PayFast form description (action URL + fields). The app opens
the checkout in the EXTERNAL browser (url_launcher). 409 `{ error: "already_subscribed" }`.
After returning to the app, `/api/me` is called again (payment confirmation
arrives server-side via PayFast ITN).

## POST /api/payfast/cancel

200 `{ ok: true, ...entitlement }`   400 `{ error: "no_active_subscription" }`
502 `{ error: "payfast_cancel_failed" }`

## Admin (all require `is_admin`; 403 `{"error":"admin_required"}` otherwise)

- GET  /api/admin/users?q=<text>
  200 `{ users: [{user_id, email, status, state, created_at}] }`
- POST /api/admin/centres
  body `{region, name, address, phone, lat, lng}` → 201 `{centre: {...}}`
  400 `{error:"invalid_centre", fields:[...]}`   409 `{error:"duplicate_centre"}`
- POST /api/admin/users/reset-password
  body `{user_id}` → 200 `{email, temporary_password}`
  The server sets `must_change_password` on that account. The app shows the
  password once and never stores it.
- POST /api/admin/users/delete
  body `{user_id}` → 200 `{ok:true, subscription_cancelled: bool}`
  409 `{error:"cannot_delete_self"}`   502 `{error:"payfast_cancel_failed"}`
  (on 502 nothing is deleted).

## Access rules to mirror (server decides; app only displays)

- 7-day free trial from the first `/api/me`, then R100/month via PayFast;
  a 3-day grace period after a missed payment.
- Cancelled subscriptions keep access until the paid-through date.
- The last confirmed entitlement is cached locally so the app works offline
  until that date; the cache is never authoritative when online, and being
  offline never signs anyone out.
- A cached `must_change_password` still blocks entry: that one can only be
  cleared online.
- Store builds (`kStoreBuild = true`): hide every purchase / subscribe /
  cancel control — including the trial page's "Pay now" — keeping sign-in and
  status only.
