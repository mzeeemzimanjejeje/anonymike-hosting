---
name: server.mjs is the compiled source of truth
description: All backend logic lives in server.mjs; src/ files are stubs only
---

## Rule
**Edit `artifacts/api-server/server.mjs` directly** for any backend changes. The TypeScript files in `artifacts/api-server/src/` are template stubs (5 files total) — they do NOT contain the real business logic and rebuilding from them would destroy it.

**Why:** The original TypeScript source was compiled into `server.mjs` via esbuild and is not preserved in the repo. The bundle is ~62k lines.

**How to apply:** Use grep/sed to locate insertion points in server.mjs, then use Edit tool with sufficient context (5-10 lines) for unique matching. After edits, restart the `artifacts/api-server: API Server` workflow.

## URL normalization (added)
`PTERODACTYL_URL` is auto-normalized: if the value lacks `https://`, the server prepends it. So `apps.courtneytech.xyz` and `https://apps.courtneytech.xyz` both work.

## DB schema
Schema lives in `artifacts/api-server/schema.sql`. Apply via `executeSql` in CodeExecution — drizzle-kit push targets the `lib/db` stub package and won't find the real schema.
