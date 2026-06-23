# Security Notes

Operational and design notes for the security posture of 500words. The active
task list lives in `TODO.md`; this document captures decisions and plans for
items that are intentionally deferred or that describe how to run the app safely.

## Password reset & email verification (planned, not yet built)

The app currently has no password-reset or email-verification flow. This is a
deliberate gap — there are no reset tokens to attack yet — but it is the most
likely next feature and the most common place new authentication bugs are
introduced. When building it, follow these constraints:

- **Tokens:** Use Rails' `generates_token_for` with a short expiry (e.g. 15
  minutes for reset, longer for verification) and embed a value that changes
  once the token is used (such as `password_salt` for reset) so the token is
  effectively single-use.
- **No enumeration:** The "forgot password" and "resend verification" responses
  must be identical whether or not the address is registered (always "If that
  email exists, we've sent a link"). Never branch the visible response on
  account existence. Pair with a rate limit, mirroring `sessions#create` and
  `users#create`.
- **Session invalidation:** On a successful password change, destroy all of the
  user's `Session` records (now that sessions are DB-backed — see the
  `Session` model and `Authentication` concern) so any stolen session is
  revoked. `has_secure_password` rotating the digest also invalidates any
  outstanding reset tokens derived from it.
- **Delivery:** Production SMTP is not yet configured (`config.action_mailer`
  is stubbed). Wire real SMTP credentials via `rails credentials:edit` before
  enabling any email-bearing flow, and confirm `config.action_mailer.default_url_options`
  points at the real host (already set to the Fly app host / `APP_HOST`).
- **Mailer framework:** Action Mailer is loaded; Action Mailbox/Action Text are
  intentionally not (see `config/application.rb`). Outbound reset/verification
  email needs only Action Mailer, so no framework change is required.
