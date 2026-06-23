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

## Cookie & logging review

Reviewed and confirmed correct; recorded here so it stays correct:

- **Auth cookie:** The `session_id` cookie is signed, `HttpOnly`, `SameSite=Lax`,
  and `Secure` in production (set explicitly in the `Authentication` concern in
  addition to `force_ssl` upgrading cookies). `SameSite=Strict` was considered
  and rejected — it would make a user arriving from an external link appear
  logged out. Revisit only if the app stops relying on cross-site entry.
- **Transport:** `config.force_ssl` and `config.assume_ssl` are on in
  production, so all cookies (session + CSRF) are flagged `Secure` and HSTS is
  sent.
- **Log parameter filtering:** `config/initializers/filter_parameter_logging.rb`
  filters `passw`, `email`, `secret`, `token`, `_key`, `crypt`, `salt`, etc.,
  so credentials and PII are redacted from logs.
- **Log level:** Production logs at `info` (`RAILS_LOG_LEVEL`), not `debug`, so
  raw request parameters are not written to logs. Do not lower this in
  production.

## Production data operations

The entire datastore is a single SQLite file on a Fly volume. Treat it
accordingly:

- **Storage layout:** Production runs on Fly with `DATABASE_URL=sqlite3:///data/production.sqlite3`
  (see `fly.toml`) on a mounted volume at `/data`. The primary DB plus the
  Solid Queue/Cache/Cable databases all live there.
- **Backups:** A single file is the whole database — back it up on a schedule.
  Either enable Fly volume snapshots (`fly volumes snapshots`) or run a periodic
  `sqlite3 /data/production.sqlite3 ".backup '/data/backup-<timestamp>.sqlite3'"`
  (use `.backup`, not a file copy, so the snapshot is consistent under
  concurrent writes) and ship it off-box. Periodically test a restore.
- **Volume permissions:** The container runs as the non-root `rails` user
  (uid/gid 1000) and the image chowns `db log storage tmp` to it (see
  `Dockerfile`). Confirm `/data` is writable only by that user and not exposed
  to other processes on the machine.
- **Required secrets:** `RAILS_MASTER_KEY` decrypts `config/credentials.yml.enc`
  and must be supplied as a Fly secret (`fly secrets set RAILS_MASTER_KEY=...`),
  never committed — `config/master.key` is git-ignored. `SECRET_KEY_BASE` is
  derived from the master key unless explicitly overridden. When SMTP is added,
  its credentials belong in encrypted credentials or Fly secrets, not in source.
