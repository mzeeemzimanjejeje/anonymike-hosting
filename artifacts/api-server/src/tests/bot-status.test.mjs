/**
 * Unit + integration-style tests for bot status reconciliation logic.
 *
 * All three functions under test are imported from the REAL production module
 * (src/lib/bot-status.mjs) — the same file that server.mjs uses at runtime.
 * Mocks are only supplied for external I/O boundaries (db, pterodactyl client,
 * logger) so that the business logic paths are fully exercised.
 *
 * Run with:  node --test src/tests/bot-status.test.mjs
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";

// ── Real production exports ──────────────────────────────────────────────────
import {
  mapPteroStatus,
  makeLiveStatus,
  makeReconcile,
} from "../lib/bot-status.mjs";

// ---------------------------------------------------------------------------
// Shared mock builders
// ---------------------------------------------------------------------------

function noop() {}
const silentLogger = { info: noop, warn: noop, error: noop };

/**
 * Minimal chainable db mock that records calls to update().set().where().
 * `updateLog` accumulates { data, cond } entries for assertion.
 */
function buildDbUpdateMock(updateLog) {
  return {
    update: () => ({
      set: (data) => ({
        where: (cond) => {
          updateLog.push({ data, cond });
          return Promise.resolve();
        },
      }),
    }),
    select: () => ({
      from: () => ({
        where: () => Promise.resolve([]),
      }),
    }),
  };
}

// ---------------------------------------------------------------------------
// 1. mapPteroStatus — pure unit tests
// ---------------------------------------------------------------------------

describe("mapPteroStatus", () => {
  it("returns 'stopped' for null", () => {
    assert.equal(mapPteroStatus(null), "stopped");
  });

  it("returns 'stopped' for undefined", () => {
    assert.equal(mapPteroStatus(undefined), "stopped");
  });

  it("returns 'stopped' for empty string", () => {
    assert.equal(mapPteroStatus(""), "stopped");
  });

  it("passes through 'running'", () => {
    assert.equal(mapPteroStatus("running"), "running");
  });

  it("passes through 'starting'", () => {
    assert.equal(mapPteroStatus("starting"), "starting");
  });

  it("passes through 'stopping'", () => {
    assert.equal(mapPteroStatus("stopping"), "stopping");
  });

  it("passes through 'offline' (panel-specific value)", () => {
    assert.equal(mapPteroStatus("offline"), "offline");
  });

  it("passes through any unknown panel value verbatim", () => {
    assert.equal(mapPteroStatus("installing"), "installing");
  });
});

// ---------------------------------------------------------------------------
// 2. getLiveStatus (via makeLiveStatus factory) — unit tests with mocks
// ---------------------------------------------------------------------------

describe("getLiveStatus", () => {
  it("returns bot.status when no pterodactylServerId", async () => {
    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => "running" },
      db: buildDbUpdateMock([]),
      botsTable: {},
      eq: () => {},
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "a", pterodactylServerId: null, status: "starting" });
    assert.equal(result, "starting");
  });

  it("returns bot.status when client access is unavailable", async () => {
    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => false, getServerStatus: async () => "running" },
      db: buildDbUpdateMock([]),
      botsTable: {},
      eq: () => {},
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "b", pterodactylServerId: "abc123", status: "stopping" });
    assert.equal(result, "stopping");
  });

  it("returns live status and does NOT update DB when status is already in sync", async () => {
    const updateLog = [];
    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => "running" },
      db: buildDbUpdateMock(updateLog),
      botsTable: {},
      eq: () => {},
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "c", pterodactylServerId: "srv1", status: "running" });
    assert.equal(result, "running");
    assert.equal(updateLog.length, 0, "DB should not be written when panel agrees with DB");
  });

  it("updates DB and returns new status when panel reports 'running' but DB shows 'starting'", async () => {
    const updateLog = [];
    const db = {
      update: () => ({
        set: (data) => ({
          where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); },
        }),
      }),
    };

    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => "running" },
      db,
      botsTable: { id: "id_col" },
      eq: (col, val) => ({ col, val }),
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "d", pterodactylServerId: "srv2", status: "starting" });
    assert.equal(result, "running", "Should return the live panel status");
    assert.equal(updateLog.length, 1, "DB update should be called exactly once");
    assert.deepEqual(updateLog[0].data, { status: "running" }, "Should persist the new status");
  });

  it("updates DB to 'stopped' when panel returns null (container fully offline) and DB shows 'stopping'", async () => {
    const updateLog = [];
    const db = {
      update: () => ({
        set: (data) => ({
          where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); },
        }),
      }),
    };

    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => null },
      db,
      botsTable: { id: "id_col" },
      eq: (col, val) => ({ col, val }),
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "e", pterodactylServerId: "srv3", status: "stopping" });
    assert.equal(result, "stopped");
    assert.equal(updateLog.length, 1);
    assert.deepEqual(updateLog[0].data, { status: "stopped" });
  });

  it("falls back to bot.status and does not throw when the panel call fails", async () => {
    const getLiveStatus = makeLiveStatus({
      pterodactyl: {
        hasClientAccess: () => true,
        getServerStatus: async () => { throw new Error("panel timeout"); },
      },
      db: buildDbUpdateMock([]),
      botsTable: {},
      eq: () => {},
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "f", pterodactylServerId: "srv4", status: "starting" });
    assert.equal(result, "starting", "Should fall back to DB status on panel error");
  });

  it("does not update DB when panel still shows 'stopping' and DB also shows 'stopping'", async () => {
    const updateLog = [];
    const getLiveStatus = makeLiveStatus({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => "stopping" },
      db: buildDbUpdateMock(updateLog),
      botsTable: {},
      eq: () => {},
      logger: silentLogger,
    });

    const result = await getLiveStatus({ id: "g", pterodactylServerId: "srv5", status: "stopping" });
    assert.equal(result, "stopping");
    assert.equal(updateLog.length, 0, "No update needed when panel and DB agree");
  });
});

// ---------------------------------------------------------------------------
// 3. reconcileBotStatuses (via makeReconcile factory) — integration-style
// ---------------------------------------------------------------------------

describe("reconcileBotStatuses", () => {
  it("does nothing when client access is unavailable", async () => {
    const reconcileBotStatuses = makeReconcile({
      pterodactyl: { hasClientAccess: () => false },
      db: null,      // would throw if touched
      botsTable: null,
      and: () => {},
      isNotNull: () => {},
      inArray: () => {},
      eq: () => {},
    });

    await assert.doesNotReject(reconcileBotStatuses());
  });

  it("does nothing when there are no transient-state bots", async () => {
    const panelCalls = [];
    const db = {
      select: () => ({ from: () => ({ where: () => Promise.resolve([]) }) }),
      update: () => ({ set: () => ({ where: () => Promise.resolve() }) }),
    };

    const reconcileBotStatuses = makeReconcile({
      pterodactyl: {
        hasClientAccess: () => true,
        getServerStatus: async (id) => { panelCalls.push(id); return "running"; },
      },
      db,
      botsTable: {},
      and: (...args) => args,
      isNotNull: (col) => ({ isNotNull: col }),
      inArray: (col, vals) => ({ inArray: col, vals }),
      eq: (col, val) => ({ col, val }),
    });

    await reconcileBotStatuses();
    assert.equal(panelCalls.length, 0, "Panel should not be called when no bots need reconciling");
  });

  it("updates a 'starting' bot whose panel state is now 'running'", async () => {
    const bots = [{ id: "bot-1", pterodactylServerId: "srv-1", status: "starting" }];
    const updateLog = [];

    const db = {
      select: () => ({ from: () => ({ where: () => Promise.resolve(bots) }) }),
      update: () => ({
        set: (data) => ({ where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); } }),
      }),
    };

    const reconcileBotStatuses = makeReconcile({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => "running" },
      db,
      botsTable: { id: "id_col" },
      and: (...args) => args,
      isNotNull: () => {},
      inArray: () => {},
      eq: (col, val) => ({ col, val }),
    });

    await reconcileBotStatuses();
    assert.equal(updateLog.length, 1, "Should update the bot whose status changed");
    assert.deepEqual(updateLog[0].data, { status: "running" });
  });

  it("updates a 'stopping' bot whose panel reports null (container fully offline)", async () => {
    const bots = [{ id: "bot-2", pterodactylServerId: "srv-2", status: "stopping" }];
    const updateLog = [];

    const db = {
      select: () => ({ from: () => ({ where: () => Promise.resolve(bots) }) }),
      update: () => ({
        set: (data) => ({ where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); } }),
      }),
    };

    const reconcileBotStatuses = makeReconcile({
      pterodactyl: { hasClientAccess: () => true, getServerStatus: async () => null },
      db,
      botsTable: { id: "id_col" },
      and: (...args) => args,
      isNotNull: () => {},
      inArray: () => {},
      eq: (col, val) => ({ col, val }),
    });

    await reconcileBotStatuses();
    assert.equal(updateLog.length, 1);
    assert.deepEqual(updateLog[0].data, { status: "stopped" });
  });

  it("continues reconciling remaining bots even when one panel call fails", async () => {
    const bots = [
      { id: "bot-3", pterodactylServerId: "srv-ok",   status: "starting" },
      { id: "bot-4", pterodactylServerId: "srv-fail", status: "starting" },
      { id: "bot-5", pterodactylServerId: "srv-same", status: "running"  },
    ];
    const updateLog = [];

    const db = {
      select: () => ({ from: () => ({ where: () => Promise.resolve(bots) }) }),
      update: () => ({
        set: (data) => ({ where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); } }),
      }),
    };

    const reconcileBotStatuses = makeReconcile({
      pterodactyl: {
        hasClientAccess: () => true,
        getServerStatus: async (id) => {
          if (id === "srv-ok")   return "running";
          if (id === "srv-fail") throw new Error("network error");
          if (id === "srv-same") return "running";
        },
      },
      db,
      botsTable: { id: "id_col" },
      and: (...args) => args,
      isNotNull: () => {},
      inArray: () => {},
      eq: (col, val) => ({ col, val }),
    });

    await assert.doesNotReject(reconcileBotStatuses());

    // bot-3: starting → running (update expected)
    // bot-4: panel error  (no update; error swallowed)
    // bot-5: running → running (no change; no update)
    assert.equal(updateLog.length, 1, "Only the successfully-reconciled changed bot should be written");
    assert.deepEqual(updateLog[0].data, { status: "running" });
  });

  it("handles all four Pterodactyl state values without throwing", async () => {
    // DB status for every bot: "starting"
    // Panel returns: "offline", "running", "starting", "stopping" (one each)
    // "starting" → "starting" is a no-op → 3 updates expected
    const panelStates = ["offline", "running", "starting", "stopping"];
    const bots = panelStates.map((_, i) => ({
      id: `bot-${i}`,
      pterodactylServerId: `srv-${i}`,
      status: "starting",
    }));

    const updateLog = [];
    const db = {
      select: () => ({ from: () => ({ where: () => Promise.resolve(bots) }) }),
      update: () => ({
        set: (data) => ({ where: (cond) => { updateLog.push({ data, cond }); return Promise.resolve(); } }),
      }),
    };

    let callIndex = 0;
    const reconcileBotStatuses = makeReconcile({
      pterodactyl: {
        hasClientAccess: () => true,
        getServerStatus: async () => panelStates[callIndex++],
      },
      db,
      botsTable: { id: "id_col" },
      and: (...args) => args,
      isNotNull: () => {},
      inArray: () => {},
      eq: (col, val) => ({ col, val }),
    });

    await assert.doesNotReject(reconcileBotStatuses());

    // "offline", "running", "stopping" all differ from DB "starting" → 3 updates
    // "starting" matches DB "starting" → no update
    assert.equal(updateLog.length, 3, "Bots whose panel state differs from DB should all be updated");
    const updatedStatuses = updateLog.map((u) => u.data.status).sort();
    assert.deepEqual(updatedStatuses, ["offline", "running", "stopping"].sort());
  });
});
