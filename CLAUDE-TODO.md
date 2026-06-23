# Security Assessment — 500words

**Date:** 2026-06-23
**Scope:** Full application security review — authentication, authorization, session management, web/SQL/XSS surface, configuration, and deployment.
**Stack:** Rails 8.1, Ruby 3.3.2, SQLite, Puma/Thruster, cookie sessions, `has_secure_password` (bcrypt), Hotwire (Turbo/Stimulus), importmap, deployed on Fly.io.

Reference patterns for fixes are drawn from Basecamp's
[once-campfire](https://github.com/basecamp/once-campfire) and
[fizzy](https://github.com/basecamp/fizzy), both of which use the Rails 8
authentication conventions (DB-backed `Session` records, `Current` attributes,
`authenticate_by`, and `rate_limit`).

---

## Baseline (verified clean)

These were checked and found to be **not** vulnerable — listed so reviewers don't re-flag them:

- **SQL injection:** All data access uses ActiveRecord finders (`find_by(email:)`, `find`, scoped associations). No raw SQL, string interpolation, or dynamic finders. ✅
- **Mass assignment:** Strong parameters used in both controllers (`user_params`, `post_params`). No sensitive/role attributes exist to escalate to. ✅
- **CSRF:** `protect_from_forgery` is on by default (Rails 8 defaults, no `skip_forgery_protection` anywhere); `csrf_meta_tags` present in layout. ✅
- **Stored XSS:** All user data (`username`, `email`, post content) rendered through ERB auto-escaping; post body uses `simple_format`, which sanitizes by default. ✅
- **Output of secrets:** `.kamal/secrets` uses ENV interpolation only (no raw credentials); `config/master.key` is git-ignored. ✅
- **Transport:** `config.force_ssl = true` and `config.assume_ssl = true` in production → HSTS + secure cookies. ✅
- **Brakeman:** Runs clean (0 warnings) — the findings below are design-level issues static analysis does not detect.

---

## Findings & Tasks

Severity legend: 🔴 High · 🟠 Medium · 🟡 Low · ⚪ Informational

---

### 🔴 1. Session fixation — session is never reset on login or logout

**Where:** `app/controllers/sessions_controller.rb:9` (`session[:user_id] = user.id`), `:18` (`session[:user_id] = nil`); `app/controllers/users_controller.rb:13`.

The session identifier is reused across the privilege boundary. An attacker who can fix a victim's pre-auth session (e.g. via a planted cookie) retains an authenticated session after the victim logs in. Logout only nulls one key and leaves the rest of the session intact.

**Fix:** Reset the session on every authentication state change.
- On successful login: call `reset_session` **before** assigning the user, then set the identifier.
- On logout: replace `session[:user_id] = nil` with `reset_session`.
- Apply the same to `UsersController#create`, which logs the new user in.

Campfire/fizzy avoid this entirely by minting a fresh DB-backed `Session` record on sign-in and deleting it on sign-out (see Task 6).

---

### 🔴 2. No rate limiting on authentication endpoints (brute force / credential stuffing)

**Where:** `sessions#create` (`POST /login`), `users#create` (`POST /users` signup).

There is no throttling anywhere in the app. Login and signup accept unlimited attempts, enabling password brute-force, credential stuffing, and signup spam.

**Fix:** Use the Rails 8 built-in `rate_limit` (the exact mechanism campfire/fizzy use), e.g. in `SessionsController`:
```ruby
rate_limit to: 10, within: 3.minutes, only: :create,
  with: -> { redirect_to login_path, alert: "Try again later." }
```
Add an equivalent limit to `users#create`. Note `rate_limit` requires a cache store — `solid_cache` is already configured. For network-level limits (per-IP across endpoints) consider adding `rack-attack`.

---

### 🟠 3. Login is vulnerable to timing-based user enumeration

**Where:** `app/controllers/sessions_controller.rb:6-8`.

```ruby
user = User.find_by(email: params[:email])
if user&.authenticate(params[:password])
```
When the email does not exist, no bcrypt comparison runs, so the response returns measurably faster than for a valid email with a wrong password. This is a timing oracle that reveals which emails are registered.

**Fix:** Use `User.authenticate_by` (Rails 8 / `has_secure_password`), which performs a constant-time dummy hash when the record is missing — this is the campfire/fizzy pattern:
```ruby
if (user = User.authenticate_by(email: params[:email], password: params[:password]))
  reset_session
  session[:user_id] = user.id
  redirect_to root_path, notice: "Logged in."
else
  flash.now[:alert] = "Invalid email or password."
  render :new, status: :unprocessable_entity
end
```
(The generic error message is already correct — keep it.)

---

### 🟠 4. No Content Security Policy

**Where:** `config/initializers/content_security_policy.rb` — entirely commented out.

There is no CSP header. If any sanitization gap is ever introduced (e.g. a future `html_safe`/`raw`, or a `simple_format` bypass), there is no second line of defense against script injection. The app uses importmaps and inline Stimulus data attributes, so a nonce-based policy fits.

**Fix:** Enable a restrictive CSP with `default_src :self`, `object_src :none`, and a nonce generator for `script-src`/`style-src` (the commented template in the file is a good starting point). Tighten and test against Turbo/Stimulus/importmap before enforcing; optionally start in `report_only` mode.

---

### 🟠 5. No host authorization (DNS rebinding / Host-header attacks)

**Where:** `config/environments/production.rb` — `config.hosts` block commented out.

With no allow-list, the app responds to arbitrary `Host` headers. This enables DNS-rebinding and host-header poisoning (cache poisoning, password-reset link spoofing if such a flow is added later).

**Fix:** Set `config.hosts` to the production domain(s) and keep the `/up` health-check exclusion:
```ruby
config.hosts = ["yourdomain.com", /.*\.yourdomain\.com/]
config.host_authorization = { exclude: ->(req) { req.path == "/up" } }
```

---

### 🟠 6. Cookie-only sessions cannot be revoked server-side

**Where:** `app/controllers/application_controller.rb:9-11` — identity derives solely from `session[:user_id]` in the encrypted cookie. No `Session` model exists.

There is no way to revoke a stolen session, list active sessions, or "sign out everywhere." A leaked session cookie is valid until expiry regardless of password changes.

**Fix (architectural, matches campfire/fizzy):** Introduce a DB-backed `Session` model (`user`, `token`, `user_agent`, `ip_address`, `last_active_at`). Store the opaque token in a signed/encrypted cookie; resolve `Current.user` by looking up the live `Session` row each request. This enables revocation, session listing, and invalidating sessions on password change. Pairs naturally with `Current` attributes for `current_user`.

---

### 🟡 7. Weak password policy

**Where:** `app/models/user.rb:7` — `length: { minimum: 6 }`.

Six characters is below current guidance and makes the (currently unthrottled) brute-force surface worse.

**Fix:** Raise the minimum (e.g. 8–12) and add a maximum (~72 bytes — bcrypt's hard limit; longer input is silently truncated, which is itself a subtle correctness/security issue). Optionally check against a common-password list.

---

### 🟡 8. User enumeration via signup validation errors

**Where:** `app/models/user.rb:5-6` + `app/views/users/new.html.erb` rendering `@user.errors.full_messages`.

Uniqueness validations surface "Email has already been taken" / "Username has already been taken" directly to the visitor, confirming which emails/usernames are registered. Combined with no rate limit (Task 2), this allows bulk account discovery.

**Fix:** This is a known trade-off (campfire/fizzy accept it for usability). At minimum, gate it behind the signup rate limit from Task 2. For stronger privacy, move to an email-verification flow where existence is never confirmed in the synchronous response.

---

### 🟡 9. No password-reset or email-verification flow

**Where:** Routes/controllers — absent. Emails are never verified; there is no recovery path.

Not a vulnerability today (and it means there are no insecure reset tokens to attack), but flagged because (a) it's a likely next feature and (b) password reset is the most common place new auth vulnerabilities are introduced. When added, use Rails 8 `generates_token_for` with short expiry and single-use semantics (the campfire/fizzy approach), and ensure reset does not leak account existence.

---

### 🟡 10. Redundant / confusing authorization in PostsController

**Where:** `app/controllers/posts_controller.rb:3-4, 45-53`.

`set_post` already scopes to `current_user.posts.find(...)`, so a non-owner gets `RecordNotFound` → `head :unauthorized`. The separate `authorize_user!` (`@post.user == current_user`) can therefore never fail. The logic is correct (posts are properly owner-scoped) but the duplication invites future mistakes — e.g. someone "simplifies" `set_post` to `Post.find` without realizing `authorize_user!` redirects rather than 404s, or that `show` would then leak other users' posts.

**Fix:** Keep a single, intentional authorization strategy. Either rely on association scoping (and drop `authorize_user!`), or fetch with `Post.find` and rely solely on an explicit policy check — not both with overlapping responsibilities. Document which guards the boundary. (Low priority; not currently exploitable.)

---

### 🟠 11. No length limit on post content (resource exhaustion / DoS)

**Where:** `app/models/post.rb` (validates `content` for `presence` only); `app/controllers/posts_controller.rb#create/#update` permit unbounded `:content`.

Post content has no maximum size. A user can submit an arbitrarily large body; on every save `before_save :calculate_word_count` runs `content.split` over the entire string in memory, and each view re-renders the full text through `simple_format`. Large inputs translate into CPU/memory pressure and oversized rows — a cheap denial-of-service for an app whose entire premise is a ~500-word target.

**Fix:** Bound the input at the model layer (and optionally the DB):
```ruby
validates :content, presence: true, length: { maximum: 50_000 }
```
Choose a ceiling that comfortably clears the 500-word goal but caps abuse. Campfire/fizzy similarly bound user-submitted bodies rather than trusting client input.

---

### 🟡 12. Missing database-level integrity constraints on `users`

**Where:** `db/schema.rb` / `db/migrate/20250508062831_create_users.rb`.

Uniqueness of `email` and `username` is enforced only by ActiveRecord validations, and the `email` index (`index_users_on_email`) is **non-unique**. Under concurrent signups, two requests can both pass the validation and insert duplicate accounts (classic validation race). The `email`, `username`, and `password_digest` columns are also nullable in the schema.

**Fix:** Enforce invariants in the database, not just the model:
- Add `null: false` to `email`, `username`, `password_digest`.
- Replace the plain `email` index with a **unique** index, and add a unique index on `username`.
```ruby
add_index :users, :email, unique: true
add_index :users, :username, unique: true
change_column_null :users, :email, false
change_column_null :users, :username, false
change_column_null :users, :password_digest, false
```
(Backfill/de-dupe any existing rows before adding the unique indexes.)

---

### ⚪ 13. Hardening & process recommendations

- **Run Brakeman in CI.** The gem is already in the `:development, :test` group; add a CI step (`bundle exec brakeman`) so regressions are caught on every PR.
- **Dependency scanning.** Dependabot is active (recent commits) — keep `rails`, `rack`, `nokogiri`, `bcrypt` current; add `bundler-audit` to CI for CVE alerts.
- **Session cookie attributes.** Rails defaults give `HttpOnly` + `SameSite=Lax`; with `force_ssl` they're also `Secure`. Confirm no future change weakens these; consider `SameSite=Strict` for the session cookie.
- **`log_level` / PII.** Production logs at `info` and `filter_parameter_logging.rb` filters `:passw`, `:email`, etc. — good. Verify nothing logs raw params at `debug` in production.
- **SQLite in production.** Acceptable for this app's scale, but ensure the Fly volume (`/data`) is backed up and access-controlled; a single file is the whole datastore.

---

## Suggested order of work

1. Task 1 (session fixation) + Task 3 (`authenticate_by`) — small, same file, high impact.
2. Task 2 (rate limiting) — blocks brute force; depends on solid_cache (already present).
3. Task 5 (host authorization) + Task 4 (CSP) — config-only hardening.
4. Task 11 (content length limit) + Task 7 (password policy) + Task 12 (DB constraints) — model/migration changes.
5. Task 13 (Brakeman/bundler-audit in CI).
6. Task 6 (DB-backed sessions) — larger refactor; do when revocation/multi-device is needed.
7. Tasks 8, 9, 10 — address alongside the next auth feature.
