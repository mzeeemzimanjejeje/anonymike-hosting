---
name: Pterodactyl dual-key architecture
description: Why two separate API keys are required and how they are used
---

## Rule
Always configure TWO separate Pterodactyl keys:
- `PTERODACTYL_API_KEY` — Application key (`ptla_…`): server CRUD via `/api/application/…`
- `PTERODACTYL_CLIENT_KEY` — Client key (`ptlc_…`): power signals, file writes, resource monitoring via `/api/client/…`

**Why:** Pterodactyl enforces strict key-type separation at the API level. Sending an Application key to a client endpoint returns HTTP 403: "You are attempting to use an application API key on an endpoint that requires a client API key." This is not a config error — it is by design.

**How to apply:** In `server.mjs`, `clientRequest()` and direct client fetches use `CLIENT_KEY`; `appRequest()` uses `KEY`. The `isConfigured()` check requires `CLIENT_KEY` (sufficient for power/status ops even without an app key). The `isAppKey()` check gates createServer/deleteServerFromPanel.

**Panel verified:** apps.courtneytech.xyz — Application API sees 45 servers; Client API sees 3.
