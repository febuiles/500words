# Security Hardening — Overview of Changes

Summary of the security review remediation completed on the 500words app. Every
item from the original assessment was addressed; ongoing operational and design
notes live in `SECURITY.md`. The test suite grew from 13 to 31 tests, and
Brakeman, bundler-audit, and RuboCop all run clean.

## Environment

- **Ruby pinned to 3.3.2** across `.ruby-version`, `.tool-versions`, and the
  Dockerfile `RUBY_VERSION` so local (asdf), CI, and the production image build
  on the same interpreter. (`30c4853`)

## Authentication & sessions

- **Session fixation closed** — `reset_session` on login and signup, full
  teardown on logout. (`ca39a37`)
- **DB-backed `Session` model + `Current`** — identity now resolves from a
  persisted session (user, ip, user-agent) behind a signed, HttpOnly,
  SameSite=Lax, Secure-in-production cookie, enabling server-side revocation.
  (`c1553bf`, `dc57087`)
- **Timing-safe login** — `User.authenticate_by` replaces `find_by` +
  `authenticate`, removing the email-enumeration timing oracle; lookup is
  case/whitespace-normalized. (`d470643`)
- **Rate limiting** — login (10 / 3 min) and signup (5 / 3 min), keyed by IP.
  (`b463527`)
- **Stronger password policy** — minimum raised 6 → 8, explicit 72-byte
  maximum (bcrypt truncation). (`a8f8580`)

## Authorization

- **Centralized `Authentication` concern** and a single, non-revealing
  authorization boundary for posts (owner-scoped lookup → consistent 404
  instead of a 401 that leaked existence). Cross-user tests added for show,
  edit, update, and destroy. (`b3217a4`)

## Data integrity & input limits

- **Normalized + constrained identity fields** — email downcased/stripped and
  matched case-insensitively, usernames stripped, model length caps. (`5875dec`)
- **Database-level constraints** — NOT NULL on key columns, unique indexes on
  email and username (closing the concurrent-signup duplicate race), and a
  non-negative CHECK + default on `word_count`. (`3e158ed`)
- **Post content bounded** at 50KB via model validation + a DB CHECK constraint,
  preventing oversized-write / word-count DoS. (`93675e5`)
- **Signup enumeration reduced** — neutral email uniqueness message on top of
  the signup rate limit. (`554e99c`)

## Configuration & transport

- **Production host authorization** — `config.hosts` set (Fly host / `APP_HOST`)
  with a `/up` exclusion, blocking DNS-rebinding / host-header attacks; mailer
  host de-placeholdered. (`cd94325`)
- **Content Security Policy** — restrictive nonce-based policy (default-src
  'self', object-src 'none', frame-ancestors 'none', …), importmap/Turbo
  compatible. (`30d8231`, `7f9a17c`)
- **Reduced framework surface** — `rails/all` replaced with explicit railties,
  dropping unused Active Storage, Action Mailbox, and Action Text (and their
  exposed routes). (`8fa30f7`)

## Tooling / CI

- **bundler-audit** dependency-CVE scan added as a CI job, and the
  `bin/brakeman` `--ensure-latest` flag removed so CI tests the pinned version.
  (`fcc1d8f`)
- **Autocomplete attributes** on auth forms for password-manager support.
  (`2679b2d`)

## Documentation

- **`SECURITY.md`** records deferred/ongoing items: the password-reset &
  email-verification design, production data operations (Fly SQLite backups,
  volume permissions, secrets), and the reviewed cookie/logging defaults.
  (`3ee4052`, `18b66d9`, `dc57087`)

## Verified clean (not vulnerable)

SQL injection (parameterized AR throughout), mass assignment (strong params,
no privileged attributes), CSRF (on by default), stored XSS (ERB escaping +
`simple_format` sanitization), and committed secrets (`.kamal/secrets` uses ENV
interpolation; `master.key` git-ignored).
