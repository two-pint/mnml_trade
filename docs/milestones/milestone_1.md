# Milestone 1 — Foundation: Tickets

**Goal**: Monorepo, auth, API skeleton, and deploy pipeline so web and mobile can call a single backend.  
**HLD reference**: §12.1 Logical Milestones — Milestone 1.

---

## M1-001: Monorepo structure and tooling

### Ticket
**ID**: M1-001  
**Title**: Monorepo structure and tooling

### Description (why this ticket is needed)
The product has three applications (web, mobile, API) and shared code (types, API client, UI, config). A single repository with a defined structure and build tooling ensures consistent installs, builds, and scripts across the stack and avoids publishing internal packages. Turborepo and PNPM give fast, cacheable tasks and correct workspace resolution.

### Required tasks
- [x] Initialize root repo with `pnpm-workspace.yaml` defining `apps/*` and `packages/*`.
- [x] Add Turborepo: `turbo.json` with pipeline for `build`, `dev`, `lint`, `type-check` (and `^build` where applicable).
- [x] Create directory structure: `apps/web`, `apps/mobile`, `apps/api`, and placeholder dirs for packages.
- [x] Add root `package.json` with scripts: `dev`, `build`, `lint`, `type-check`, `clean`; use `turbo run` and filters where appropriate.
- [x] Add root `.gitignore`, `.tool-versions` (asdf) for Node.js, Elixir, and Erlang.
- [x] Document in root README how to run `pnpm install` and `pnpm dev` / `pnpm build`.

### Acceptance criteria
- Running `pnpm install` at root installs dependencies for all workspaces.
- `pnpm dev` starts dev mode for apps that define it (web, mobile); `pnpm build` builds all buildable packages/apps.
- `pnpm lint` and `pnpm type-check` run across the monorepo (or per-app where configured).
- Turborepo cache is used for repeated builds.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Clone repo, run `pnpm install` | No errors; node_modules at root and in workspaces as needed |
| 2 | Run `pnpm build` | All buildable targets complete; cache hit on second run for unchanged code |
| 3 | Run `pnpm dev` | Dev servers start for web and/or mobile per config; no workspace resolution errors |
| 4 | Run `pnpm lint` and `pnpm type-check` | Commands complete (can be no-op until apps add config) |

---

## M1-002: Shared packages (types, api-client, ui, config, utils)

### Ticket
**ID**: M1-002  
**Title**: Shared packages (types, api-client, ui, tailwind-config, typescript-config, utils)

### Description (why this ticket is needed)
Web and mobile must share TypeScript types, API client logic, and styling/config to avoid drift and duplicate fixes. Centralizing these in `packages/*` gives a single source of truth and allows the API to be called the same way from both clients. Shared packages are a prerequisite for the web and mobile apps in M1.

### Required tasks
- [x] **packages/types**: Create package with `package.json` (name e.g. `@repo/types`), tsconfig; add shared types (e.g. `User`, auth DTOs, `ApiError`). Export from `src/index.ts`.
- [x] **packages/api-client**: Create package; implement base HTTP client (base URL, optional Bearer token, JSON parse, error handling). Add auth methods: `login(email, password)`, `register(payload)`, `refresh(token)`; use types from `@repo/types`. Export client and auth helpers.
- [x] **packages/ui**: Create package with minimal shared components (e.g. `Button`, `Card`) and platform adapters (web/native) or single implementation that works with both; use `@repo/types` if needed.
- [x] **packages/tailwind-config**: Add shared Tailwind config (theme extend: primary, bullish, bearish, fonts); export for web and native presets if applicable.
- [x] **packages/typescript-config**: Add `base.json`, `nextjs.json`, `react-native.json` (or equivalent) for apps to extend.
- [x] **packages/utils**: Create package; add formatters or validators (e.g. Zod schemas for auth) used by api-client or apps; export from index.
- [x] Wire workspace refs: apps depend on `@repo/types`, `@repo/api-client`, etc. via `workspace:*`.

### Acceptance criteria
- Web and mobile can import `@repo/types`, `@repo/api-client`, `@repo/ui`, and extend shared Tailwind/TS configs.
- api-client can call a base URL with optional `Authorization: Bearer <token>`.
- No circular dependencies; `pnpm build` succeeds for all packages that have a build step.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | From `apps/web` or `apps/mobile`, import `@repo/types` and `@repo/api-client` | Imports resolve; TypeScript compiles |
| 2 | Instantiate api-client with a base URL; call `login()` (mock or real backend) | Request is sent to correct URL with JSON body; response handling does not throw for 2xx |
| 3 | Run `pnpm type-check` at root | All packages type-check |
| 4 | Use shared Tailwind theme in web app | Theme values apply (e.g. primary, bullish colors) |

---

## M1-003: Phoenix API skeleton and health endpoint

### Ticket
**ID**: M1-003  
**Title**: Phoenix API skeleton and health endpoint

### Description (why this ticket is needed)
The backend must exist in the monorepo and expose a stable base URL and health check so the frontends can target it and deployments can verify the service is up. A minimal Phoenix app with PostgreSQL and a health route establishes the API tier without auth or business logic.

### Required tasks
- [ ] Create Phoenix 1.7+ project under `apps/api` (e.g. `mix phx.new` in place or generated then moved).
- [ ] Configure PostgreSQL (dev/test/prod) via `config/*.exs` and `DATABASE_URL` where appropriate.
- [ ] Add Ecto repo; run initial migration if any (e.g. create `schema_migrations` table).
- [ ] Add JSON API pipeline: accept `application/json`, return JSON; add a router scope (e.g. `/api`).
- [ ] Implement health endpoint: `GET /api/health` or `GET /health` that checks DB connectivity (e.g. `Repo.query!("SELECT 1")`) and returns `200` with body e.g. `%{status: "ok"}`; return `503` if DB is down.
- [ ] Document in README or HLD how to run `mix setup` and `mix phx.server` and what port the API uses (e.g. 4000).

### Acceptance criteria
- `mix phx.server` starts the API; `GET /api/health` returns 200 when DB is reachable.
- When DB is unavailable, health returns 503 or equivalent failure indicator.
- API responds with JSON; no HTML routes required for M1 beyond health.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Start PostgreSQL; from `apps/api` run `mix setup` then `mix phx.server` | Server starts on configured port |
| 2 | `curl http://localhost:4000/api/health` | 200, JSON body with status |
| 3 | Stop PostgreSQL; `curl .../api/health` again | 503 or 500 with appropriate response |
| 4 | Run `mix test` | All tests pass (including health controller test if added) |

---

## M1-004: Accounts context and JWT authentication

### Ticket
**ID**: M1-004  
**Title**: Accounts context and JWT authentication

### Description (why this ticket is needed)
Users must be able to register and log in so that later milestones can scope watchlist, history, and paper trading to a user. JWT (via Guardian) provides stateless auth that works the same for web and mobile and avoids server-side session storage. The Accounts context encapsulates user lifecycle and credential handling.

### Required tasks
- [ ] Add Guardian dependency; configure JWT module (secret, issuer, ttl, etc.) in Phoenix config.
- [ ] Create User schema and migration: email (unique), password_hash, username (optional), email_verified (default false), timestamps.
- [ ] Implement Accounts context: `register_user(attrs)`, `get_user_by_email/1`, `get_user_by_id/1`; use `Bcrypt` or `Argon2` for password hashing on registration and verification on login.
- [ ] Implement token functions: `issue_access_token(user)`, `verify_token(token)` (Guardian); optionally `refresh_token` and storage in DB if using refresh tokens.
- [ ] Expose HTTP endpoints: `POST /api/auth/register` (body: email, password, username?), `POST /api/auth/login` (body: email, password). Return JSON with `token` and optional `user` (id, email, username); return 4xx with clear message for invalid credentials or duplicate email.
- [ ] Add `POST /api/auth/refresh` if using refresh tokens (body or header with refresh token); return new access token.
- [ ] Optional for M1: `POST /api/auth/forgot-password`, `POST /api/auth/reset-password` (stub or minimal implementation).
- [ ] Add tests for register (success, duplicate email), login (success, wrong password), and token verification.

### Acceptance criteria
- Registration creates a user with hashed password; duplicate email returns 422 or 409.
- Login with valid credentials returns a JWT; invalid credentials return 401.
- The returned JWT can be verified by Guardian and contains a claim that identifies the user (e.g. sub: user_id).
- Password is never stored in plain text or returned in API responses.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | POST /api/auth/register with email, password | 201 and JSON with token and user; user exists in DB with hashed password |
| 2 | POST /api/auth/register with same email again | 422 or 409; no duplicate user |
| 3 | POST /api/auth/login with correct email/password | 200 and JSON with token |
| 4 | POST /api/auth/login with wrong password | 401 |
| 5 | Decode JWT (e.g. jwt.io); verify sub and exp | Claims match user id; exp in future |
| 6 | Run `mix test` for Accounts and auth | All tests pass |

---

## M1-005: API CORS and protected route pipeline

### Ticket
**ID**: M1-005  
**Title**: API CORS and protected route pipeline

### Description (why this ticket is needed)
Web (Next.js) and mobile (Expo) run on different origins; browsers enforce CORS. The API must allow requests from the web app and from Expo dev/client origins so that both can call the same backend. Protected routes must reject requests without a valid JWT so that only authenticated users can access user-specific endpoints later.

### Required tasks
- [ ] Add CORS plug (e.g. Corsica or built-in): allow origins for local dev (e.g. `http://localhost:3000`, `http://localhost:8081`), production web domain, and Expo patterns (e.g. `exp://`, Vercel preview if needed). Allow methods: GET, POST, PUT, DELETE, OPTIONS. Allow headers: `authorization`, `content-type`. Allow credentials if using cookies.
- [ ] Create a pipeline that verifies JWT: extract `Authorization: Bearer <token>`, call Guardian to verify and load user; attach `current_user` to conn. On failure, return 401 JSON.
- [ ] Apply “public” pipeline to auth routes (register, login, refresh, forgot-password, reset-password) and health.
- [ ] Apply “protected” pipeline to a placeholder route (e.g. `GET /api/user/me` that returns current user) so that only valid JWT returns 200.
- [ ] Document allowed origins and how to add new ones (e.g. env or config list).

### Acceptance criteria
- Request from allowed origin with valid `Authorization: Bearer <token>` to a protected route returns 200 (or business response).
- Request without token or with invalid/expired token to protected route returns 401.
- OPTIONS preflight from allowed origin returns 204 with appropriate CORS headers.
- Request from a disallowed origin is rejected by CORS (browser blocks or API returns no CORS headers).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | From browser or Postman, GET /api/user/me without Authorization | 401 |
| 2 | GET /api/user/me with valid Bearer token (from login) | 200 and user payload |
| 3 | GET /api/user/me with malformed or expired token | 401 |
| 4 | Send OPTIONS to /api/auth/login with Origin: http://localhost:3000 | 204 with Access-Control-Allow-Origin and other CORS headers |
| 5 | From Next.js app (or curl with Origin header), POST login | 200 and CORS headers in response |

---

## M1-006: Next.js web app and auth UI

### Ticket
**ID**: M1-006  
**Title**: Next.js web app and auth UI

### Description (why this ticket is needed)
Users need a web interface to register and log in. The web app must use the shared API client and types so that it stays in sync with the API contract and can be reused for patterns (e.g. error handling) that mobile will also use. Protected route middleware ensures unauthenticated users cannot access app pages until they log in.

### Required tasks
- [ ] Create Next.js 14+ app in `apps/web` with App Router and TypeScript; extend `packages/typescript-config` and `packages/tailwind-config`.
- [ ] Add dependencies: `@repo/types`, `@repo/api-client`, `@repo/ui` (and `@repo/utils` if needed). Configure `NEXT_PUBLIC_API_URL` (env).
- [ ] Implement auth pages: login and register forms (email, password, optional username); client-side submit to api-client `login`/`register`; on success, store token (e.g. in memory + localStorage or httpOnly cookie if implemented); redirect to app home or dashboard.
- [ ] Implement token storage and usage: after login, set token so api-client can send `Authorization: Bearer <token>` on subsequent requests; implement logout (clear token and redirect to login).
- [ ] Add protected route handling: middleware or layout that checks for token; if missing, redirect to login. Apply to all app routes except login/register and public assets.
- [ ] Add a simple “home” or “dashboard” page after login (e.g. “Welcome” and a logout button) to verify protected flow.
- [ ] Use shared UI components and Tailwind; ensure forms show validation/error messages from API.

### Acceptance criteria
- User can open login page, enter credentials, submit; on success, is redirected and sees protected content.
- User can open register page, submit; on success, is logged in and redirected.
- Visiting a protected route without token redirects to login.
- After logout, visiting a protected route again redirects to login.
- API calls from the web app include the stored JWT and hit the configured API URL.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open app in browser; go to /login | Login form visible |
| 2 | Submit valid credentials | Redirect to home/dashboard; no redirect loop |
| 3 | Refresh page | Still logged in (token persisted) |
| 4 | Log out | Redirect to login |
| 5 | Go directly to /dashboard (or protected path) without logging in | Redirect to /login |
| 6 | Register new user; submit | Redirect to app; user can log out and log in again with new credentials |
| 7 | Submit wrong password on login | Error message shown; no redirect |

---

## M1-007: Expo mobile app and auth

### Ticket
**ID**: M1-007  
**Title**: Expo mobile app and auth

### Description (why this ticket is needed)
Mobile users need the same auth capabilities as web. The mobile app must use the same API and shared packages so that one backend and one contract serve both platforms. Storing the JWT in SecureStore (Expo) keeps the token persistent and relatively secure on device. Expo Router provides file-based routing similar to Next.js for consistency.

### Required tasks
- [ ] Create Expo app in `apps/mobile` with Expo Router (file-based); TypeScript; NativeWind for Tailwind-style styling. Extend shared typescript-config and tailwind-config.
- [ ] Add dependencies: `@repo/types`, `@repo/api-client`, `@repo/ui`, `expo-secure-store`. Configure `EXPO_PUBLIC_API_URL` (app config or env).
- [ ] Implement auth screens: login and register (email, password, optional username); call api-client `login`/`register`; on success, store token in SecureStore; navigate to app root (tabs or home).
- [ ] Implement token retrieval: on app load or before API calls, read token from SecureStore; set in api-client (or pass per request). Implement logout: clear SecureStore and navigate to login.
- [ ] Add auth guard: root layout or route group that checks for token; if missing, show login/register stack; if present, show main app (tabs or single home screen for M1).
- [ ] Add minimal home screen after login (e.g. “Welcome” and logout) to verify flow.
- [ ] Ensure API base URL is correct for device (e.g. local IP for dev, production URL for release).

### Acceptance criteria
- User can log in and register on mobile; on success, navigates to home and token is stored.
- Restarting the app with a valid token keeps the user “logged in” (home visible).
- Logout clears token and shows login again.
- Unauthenticated access to main app redirects or shows auth screens.
- All API calls use the same api-client and base URL as web (configurable per env).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open app in simulator or device; ensure API URL points to running backend | Auth screen visible |
| 2 | Log in with valid credentials | Navigate to home |
| 3 | Close and reopen app | Still on home (token from SecureStore) |
| 4 | Log out | Auth screen visible |
| 5 | Register new user | Navigate to home; can log out and log in with new user |
| 6 | Call a protected endpoint from app (e.g. GET /api/user/me) | 200 with user data when token present |

---

## M1-008: Deployment pipeline (Fly.io, Vercel, EAS)

### Ticket
**ID**: M1-008  
**Title**: Deployment pipeline (Fly.io, Vercel, EAS)

### Description (why this ticket is needed)
To validate the full stack and allow testing from real devices and shared URLs, the API and web app must deploy to production-like environments, and the mobile app must be buildable and testable via EAS. Wiring secrets and environment variables correctly ensures that auth and CORS work in production.

### Required tasks
- [ ] **Phoenix on Fly.io**: Create Fly app (or use existing); attach or create Postgres; set secrets (e.g. `SECRET_KEY_BASE`, `DATABASE_URL`). Configure `mix release` and `fly deploy`; run migrations as part of deploy or via release command. Document deploy steps.
- [ ] **Next.js on Vercel**: Connect repo (or manual deploy); set build output to `apps/web` (or root with turbo filter). Set env: `NEXT_PUBLIC_API_URL` to Phoenix URL (e.g. `https://<app>.fly.dev`). Ensure CORS on Phoenix allows Vercel origin and preview URLs.
- [ ] **EAS for mobile**: Create EAS project; configure `app.json`/`eas.json` (e.g. development build profile). Set `EXPO_PUBLIC_API_URL` in EAS env or app config to production API URL for dev builds. Document how to run `eas build --profile development` and install on device/simulator.
- [ ] Update API CORS config with production web URL and any Expo/redirect URIs if needed.
- [ ] Add a brief “Deployment” section to README or docs: how to deploy API, web, and how to build mobile for testing.

### Acceptance criteria
- Phoenix deploys to Fly.io; health endpoint returns 200 in production; DB migrations applied.
- Next.js deploys to Vercel; production URL loads; login/register work against production API (CORS allows origin).
- EAS build (development profile) produces an installable binary; app can point to production API and complete login flow.
- No secrets (API keys, DB URLs) are committed; all sensitive config via Fly/Vercel/EAS secrets or env.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Deploy Phoenix; open `https://<app>.fly.dev/api/health` | 200, JSON status |
| 2 | Deploy Next.js; open production URL | App loads; login form visible |
| 3 | Log in on production web app | Success; token stored; protected page visible |
| 4 | Run EAS build for development; install on device | App launches; can set API URL to production and log in |
| 5 | Verify CORS: from production web origin, POST to API login | 200 and CORS headers present |
| 6 | Confirm no secrets in repo (e.g. grep or audit) | No SECRET_KEY_BASE, DATABASE_URL, etc. in committed files |

---

## Milestone 1 completion checklist

- [x] M1-001: Monorepo structure and tooling
- [x] M1-002: Shared packages
- [ ] M1-003: Phoenix API skeleton and health
- [ ] M1-004: Accounts context and JWT
- [ ] M1-005: API CORS and protected pipeline
- [ ] M1-006: Next.js web app and auth UI
- [ ] M1-007: Expo mobile app and auth
- [ ] M1-008: Deployment pipeline

**Done when**: A user can register and log in on web and mobile against the same API; JWT is accepted; `pnpm dev` runs web + mobile; Phoenix and Next.js deploy successfully; health check returns 200.
