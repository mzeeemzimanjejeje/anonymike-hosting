# ANONYMIKETECH — WhatsApp Bot Platform

A bot hosting platform where users can deploy and manage WhatsApp bots through a web UI. The backend provisions and controls isolated Pterodactyl containers (Wings/Docker) for each bot, handling start/stop/restart/delete, session injection, file writes, and resource monitoring.

## Run & Operate

- `node index.js` (from `artifacts/api-server/`) — production server (reads `PORT` env var)
- Workflow: `artifacts/api-server: API Server` — runs the above automatically

## Stack

- **Runtime**: Node.js 20+, pnpm workspaces
- **API**: Express 5, compiled to `artifacts/api-server/server.mjs` via esbuild
- **DB**: PostgreSQL (Replit built-in) + Drizzle ORM
- **Frontend**: React SPA, pre-built in `artifacts/api-server/public/` (served statically when `SERVE_STATIC=true`)
- **Panel**: Pterodactyl Application + Client API

## Where things live

- `artifacts/api-server/server.mjs` — **single compiled bundle** containing all server logic (routes, services, DB schema). This is the source of truth — the `src/` stubs are templates only.
- `artifacts/api-server/schema.sql` — canonical DB schema (applied manually or via `executeSql`)
- `artifacts/api-server/public/` — pre-built React frontend
- `artifacts/api-server/index.js` — entry point; handles Replit vs VPS DB routing

## Architecture decisions

- **Compiled bundle**: All backend source is bundled into `server.mjs` via esbuild. To make backend changes, edit `server.mjs` directly (source TypeScript files in `src/` are stubs).
- **Dual Pterodactyl keys**: `PTERODACTYL_API_KEY` (Application key `ptla_…`) handles server CRUD via the App API; `PTERODACTYL_CLIENT_KEY` (Client key `ptlc_…`) handles power signals, file writes, and resource monitoring via the Client API. These are always separate keys.
- **Bot isolation**: Each bot stores its own `pterodactyl_server_id` in the `bots` table. All bot routes enforce `userId` ownership — users can never control another user's bot.
- **DB routing**: On Replit, `NEON_DATABASE_URL` (if set) is used for app data, `DATABASE_URL` (Replit built-in) for sessions. On VPS, `DATABASE_URL` handles everything.
- **Static serving**: When `SERVE_STATIC=true`, the Express server also serves the React SPA and falls back to `index.html` for all non-API routes.

## Product

- Users register/login (email, GitHub, Google, Replit OAuth)
- Users deploy WhatsApp bots by choosing a bot type, entering a session ID, and optionally linking a Pterodactyl server
- Each bot runs in an isolated Pterodactyl container (Docker via Wings)
- Users can Start / Stop / Restart / Delete / Renew bots from the dashboard
- Real-time resource metrics (CPU, RAM, Disk, Network) via `/api/bots/:id/resources`
- Activity logs via `/api/bots/:id/logs`
- Coin-based billing (M-Pesa/Payflow payments)

## Required Environment Variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres connection (auto-injected by Replit) |
| `SESSION_SECRET` | Express session signing |
| `PTERODACTYL_URL` | Panel URL e.g. `apps.courtneytech.xyz` (https:// auto-added) |
| `PTERODACTYL_API_KEY` | Application API key (`ptla_…`) — server CRUD |
| `PTERODACTYL_CLIENT_KEY` | Client API key (`ptlc_…`) — power/files/resources |
| `ADMIN_EMAILS` | Comma-separated admin email addresses |

Optional: `NEON_DATABASE_URL`, `GITHUB_CLIENT_ID/SECRET`, `GOOGLE_CLIENT_ID/SECRET`, `REPL_ID`, `PAYFLOW_API_KEY/SECRET/ACCOUNT_ID`, `RESEND_API_KEY`

## Gotchas

- **Never edit `src/` files** — they are template stubs; the real code is in `server.mjs`.
- **Pterodactyl dual-key**: Application keys (`ptla_`) cannot call client endpoints (power/resources/files) — always configure `PTERODACTYL_CLIENT_KEY` separately.
- **URL normalization**: `PTERODACTYL_URL` can be entered with or without `https://` — the server adds it automatically.
- **Schema**: DB schema lives in `schema.sql`. Push it with `executeSql` via CodeExecution, not drizzle-kit (the lib/db package is a stub).
- **Bot delete**: When `PTERODACTYL_API_KEY` is an Application key, deleting a bot also deletes the Pterodactyl server from the panel.

## Pointers

- See the `pnpm-workspace` skill for workspace structure
- Admin panel: `/1admin1` route (admin email required)
- Connection test: `GET /api/pterodactyl/test` (admin only)
