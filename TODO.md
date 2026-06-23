# Security Assessment TODO — 500words

**Date:** 2026-06-23
**Scope:** Backend/web security review of the Rails 8 app — authentication, authorization, session management, SQL/XSS/CSRF exposure, security headers, schema integrity, input limits, dependency/tooling, and deployment configuration.
**Stack:** Rails 8.1, Ruby 3.3.x, SQLite, Puma/Thruster, cookie sessions, `has_secure_password` (bcrypt), Hotwire (Turbo/Stimulus), importmap, Fly.io.

**Reference patterns:** Basecamp's [once-campfire](https://github.com/basecamp/once-campfire) and [fizzy](https://github.com/basecamp/fizzy) use authentication concerns, `Current` attributes, DB-backed `Session` records, signed HTTP-only same-site session cookies, `authenticate_by`, login `rate_limit`, and bounded user-submitted bodies. Apply those shapes where they fit.

---

## Verified Baseline

Environment / tooling (from a local run):
- asdf selects Ruby 3.3.7, `.ruby-version` matches it, and the Dockerfile Ruby ARG matches it.
- `bundle install` succeeds (Bundler 2.5.22).
- `bundle exec rails test` passes: 13 tests, 26 assertions, 0 failures.
- `bundle exec brakeman --no-pager --format text` reports **0 warnings** — every finding below is a design-level issue static analysis does not detect.
- `bundle exec rails routes` confirms signup/login/logout, users show/create, full `posts` resources, `/up`, and framework routes from Active Storage and Action Mailbox.
- `bin/brakeman` crashes before scanning because its binstub forces `--ensure-latest`; use `bundle exec brakeman` (see CI task).

Checked and **not** vulnerable (don't re-flag):
- **SQL injection:** All access via ActiveRecord finders / scoped associations. No raw SQL, interpolation, or dynamic finders. ✅
- **Mass assignment:** Strong params in both controllers (`user_params`, `post_params`); no role/privilege attributes exist. ✅
- **CSRF:** On by default (no `skip_forgery_protection`); `csrf_meta_tags` in layout. ✅
- **Stored XSS:** User data rendered via ERB auto-escaping; post body via `simple_format` (sanitizes by default). ✅
- **Secrets:** `.kamal/secrets` uses ENV interpolation only; `config/master.key` is git-ignored. ✅
- **Transport:** `force_ssl` + `assume_ssl` in production → HSTS + secure cookies. ✅

---

## Critical

- [ ] **Reset session state on every authentication boundary** (session fixation).
  `sessions_controller.rb:9` reuses the session id across login; `:18` only nulls `:user_id` on logout; `users_controller.rb:13` auto-logs-in without rotation.
  - `SessionsController#create`: call `reset_session` **before** assigning the user.
  - `SessionsController#destroy`: replace `session[:user_id] = nil` with full session termination.
  - `UsersController#create`: reset (or mint a fresh DB session) before auto-login.
  - Add regression tests proving login rotates state and logout removes all authenticated state.

- [ ] **Add rate limiting to auth + signup endpoints** (brute force / credential stuffing / spam).
  No throttling exists anywhere. Use Rails 8 `rate_limit` (campfire/fizzy pattern); `solid_cache` is already configured as the backing store.
  ```ruby
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path, alert: "Try again later." }
  ```
  - Apply to `sessions#create` and a separate limit to `users#create`.
  - Keep generic errors for throttled/failed attempts.
  - Test allowed attempts, blocked attempts, and reset after the window.

- [ ] **Replace raw `session[:user_id]` with a DB-backed `Session` model** (`application_controller.rb:9-11`).
  Cookie-only identity can't be revoked, listed, or invalidated on password change.
  - Add `Current < ActiveSupport::CurrentAttributes` with `user` and `session`.
  - Store only an opaque signed/encrypted token in an HTTP-only, same-site cookie.
  - Persist `user_agent`, `ip_address`, `last_active_at`; resolve `Current.user` from the live row each request.
  - Destroy the session record on logout. Enables revocation, session listing, and "log out everywhere."

---

## High

- [ ] **Use `User.authenticate_by` for login** (timing-based user enumeration).
  `sessions_controller.rb:6-8` does `find_by(email:)` then `authenticate`, so a missing email returns faster than a wrong password — a timing oracle. `authenticate_by` runs a constant-time dummy hash when the record is missing.
  ```ruby
  if (user = User.authenticate_by(email: params[:email], password: params[:password]))
    reset_session
    session[:user_id] = user.id   # or mint a DB Session per the Critical task
    ...
  ```
  - Normalize the email before lookup (see next task). Keep the generic "Invalid email or password" message.

- [ ] **Normalize and constrain identity fields** (`user.rb:5-6`).
  - Downcase + strip email before validation and lookup.
  - Decide case-insensitive username normalization, or explicitly document case-sensitivity.
  - Add model + DB length limits for email and username.

- [ ] **Add database-level integrity constraints** (`db/schema.rb`; uniqueness currently model-only, and `index_users_on_email` is **non-unique** → concurrent-signup duplicate-account race).
  ```ruby
  add_index :users, :email, unique: true       # backfill/de-dupe first
  add_index :users, :username, unique: true
  change_column_null :users, :email, false
  change_column_null :users, :username, false
  change_column_null :users, :password_digest, false
  change_column_null :posts, :content, false
  change_column_null :posts, :word_count, false
  ```
  - Add a default + non-negative check for `posts.word_count`.
  - Keep model validations, but don't rely on them as the only integrity boundary.

- [ ] **Bound post content length** (resource exhaustion / DoS) — `post.rb` validates `content` for presence only; `posts#create/#update` permit unbounded `:content`.
  Every save runs `before_save :calculate_word_count` → `content.split` over the whole string in memory, and every view re-renders it through `simple_format`. Unbounded input = cheap CPU/memory abuse.
  ```ruby
  validates :content, presence: true, length: { maximum: 50_000 }
  ```
  Pair with a DB-level cap (above). Choose a ceiling that clears the 500-word goal but caps abuse.

- [ ] **Tighten authorization** (`posts_controller.rb:3-4, 45-53`).
  `set_post` is owner-scoped (`current_user.posts.find`) → non-owners get `RecordNotFound` → `head :unauthorized`, so `authorize_user!` can never fire. Correct today, but the overlap invites future regressions (e.g. someone swaps to `Post.find` and `show` starts leaking other users' posts).
  - Pick one intentional strategy — owner-scoped lookup **or** explicit policy check, not both — and centralize auth in a concern instead of ad hoc helpers.
  - Return consistent `404`/`403` so existence isn't accidentally revealed.
  - Add cross-user tests for `show`, `edit`, `update`, **and** `destroy` (not just `show`).

- [ ] **Enable production host authorization** (`production.rb` — `config.hosts` commented out → DNS rebinding / host-header poisoning).
  - Set `config.hosts` to the real production domain(s); keep a `/up` health-check exclusion for Fly/Kamal.
  - Replace the placeholder mailer host `example.com` before adding any email flow.

---

## Medium

- [ ] **Enable and test Content Security Policy** (`content_security_policy.rb` fully commented out → no defense-in-depth if a sanitization gap is ever introduced).
  - Start with `default-src 'self'`, `object-src 'none'`, `base-uri 'self'`, and a nonce-backed `script-src`/`style-src` suited to importmap/Turbo/Stimulus.
  - Consider `frame-ancestors 'none'` unless embedding is required.
  - Verify no violations locally (optionally `report_only` first) before enforcing.

- [ ] **Improve password policy** (`user.rb:7` — `minimum: 6`).
  - Raise the minimum (8–12+); add a maximum near bcrypt's 72-byte input limit (longer input is silently truncated).
  - Optionally reject common passwords. Add boundary-case tests.

- [ ] **Reduce account enumeration during signup** (`user.rb:5-6` + `users/new.html.erb` rendering `errors.full_messages` → confirms registered emails/usernames).
  - At minimum, gate behind the signup rate limit.
  - For stronger privacy, move toward an email-verification flow with a generic response.

- [ ] **Review unused framework route exposure.**
  `rails/all` exposes Active Storage and Action Mailbox routes despite no uploads/inbound email. If unused, require only the frameworks the app needs to shrink attack surface; if planned, add explicit config + tests for accepted upload/email paths.

- [ ] **Add security checks to CI.**
  - `bundle exec brakeman --no-pager --format text` and `bundle exec rails test`.
  - Add `bundler-audit` (or equivalent) for dependency CVEs; Dependabot is already active — keep `rails`/`rack`/`nokogiri`/`bcrypt` current.
  - Repair or remove the `bin/brakeman` `--ensure-latest` binstub before CI relies on it.

---

## Low

- [ ] **Add autocomplete attributes to auth forms.**
  Login email `autocomplete="email"`, login password `current-password`, signup password `new-password`, signup username/email appropriate values.

- [ ] **Plan password reset & email verification before building them** (none exist today — no insecure tokens to attack yet, but it's the most common place new auth bugs land).
  Use short-lived, single-purpose Rails tokens (`generates_token_for`); never reveal whether an account exists; invalidate active sessions after password changes.

- [ ] **Review production data operations.**
  Document backup/restore for the Fly SQLite volume; confirm volume permissions are limited to the app user; document required secrets (`RAILS_MASTER_KEY`, `SECRET_KEY_BASE` if supplied, future mail credentials).

- [ ] **Keep log & cookie defaults under review.**
  Param filtering already covers password/email/token/key/secret names; `force_ssl` keeps cookies `Secure` (+ Rails defaults `HttpOnly`/`SameSite=Lax` — consider `Strict` for the session cookie). Don't enable debug param logging in production.

---

## Suggested Order

1. Session reset + `authenticate_by` (session fixation & login timing — same file, small, high impact).
2. Login/signup rate limits.
3. DB-backed sessions + `Current`.
4. DB constraints + identity normalization + post content length cap.
5. Authorization: single strategy, consistent responses, full cross-user tests.
6. Host authorization + CSP.
7. Password policy + signup-enumeration mitigation.
8. CI security checks (and fix the Brakeman binstub).
9. Reduce unused framework routes; document production data operations; auth-form autocomplete; plan reset/verification.
