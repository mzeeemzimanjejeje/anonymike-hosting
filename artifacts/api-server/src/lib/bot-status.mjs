/**
 * Bot status reconciliation logic — shared between the production server and
 * the test suite so tests exercise the real implementation.
 *
 * All three exports use dependency injection so callers can swap in real or
 * mock implementations of db / pterodactyl / logger / ORM helpers.
 */

/**
 * Maps a raw Pterodactyl panel status string to the canonical DB status value.
 *
 * The panel returns `null` / `undefined` / `""` when a container is fully
 * offline.  Everything else (including `"running"`, `"starting"`,
 * `"stopping"`) is passed through verbatim.
 *
 * @param {string | null | undefined} s
 * @returns {string}
 */
export function mapPteroStatus(s) {
  if (!s) return "stopped";
  return s;
}

/**
 * Returns a `getLiveStatus(bot)` function wired to the supplied runtime deps.
 *
 * The returned function:
 *   1. Falls back to `bot.status` if the bot has no panel server or the
 *      client key is not configured.
 *   2. Queries the panel for the live container status.
 *   3. Writes the new status to the DB when it differs from `bot.status`.
 *   4. Falls back to `bot.status` without throwing on any panel error.
 *
 * @param {{ pterodactyl, db, botsTable, eq, logger }} deps
 * @returns {(bot: object) => Promise<string>}
 */
export function makeLiveStatus({ pterodactyl, db, botsTable, eq, logger }) {
  return async function getLiveStatus(bot) {
    if (!bot.pterodactylServerId || !pterodactyl.hasClientAccess()) {
      return bot.status;
    }
    try {
      const s = await pterodactyl.getServerStatus(bot.pterodactylServerId);
      const liveStatus = mapPteroStatus(s);
      if (liveStatus !== bot.status) {
        await db
          .update(botsTable)
          .set({ status: liveStatus })
          .where(eq(botsTable.id, bot.id));
        logger.info(
          { botId: bot.id, from: bot.status, to: liveStatus },
          "Bot status reconciled from Pterodactyl panel",
        );
      }
      return liveStatus;
    } catch (err) {
      logger.warn(
        { err, botId: bot.id },
        "Failed to get live Pterodactyl status",
      );
      return bot.status;
    }
  };
}

/**
 * Returns a `reconcileBotStatuses()` function wired to the supplied runtime
 * deps.
 *
 * The returned function queries all bots in a transient state
 * (`running | starting | stopping`) that have a panel server ID and
 * reconciles each one's DB status against the live panel state.  Panel
 * errors for individual bots are swallowed so one bad server cannot block
 * the rest.
 *
 * @param {{ pterodactyl, db, botsTable, and, isNotNull, inArray, eq }} deps
 * @returns {() => Promise<PromiseSettledResult<void>[] | undefined>}
 */
export function makeReconcile({
  pterodactyl,
  db,
  botsTable,
  and,
  isNotNull,
  inArray,
  eq,
}) {
  return async function reconcileBotStatuses() {
    if (!pterodactyl.hasClientAccess()) return;

    const runningBots = await db
      .select()
      .from(botsTable)
      .where(
        and(
          isNotNull(botsTable.pterodactylServerId),
          inArray(botsTable.status, ["running", "starting", "stopping"]),
        ),
      );

    if (runningBots.length === 0) return;

    console.log(
      `[CLEANUP] Reconciling status for ${runningBots.length} active bot(s) against Pterodactyl panel\u2026`,
    );

    const results = await Promise.allSettled(
      runningBots.map(async (bot) => {
        try {
          const liveStatus = mapPteroStatus(
            await pterodactyl.getServerStatus(bot.pterodactylServerId),
          );
          if (liveStatus !== bot.status) {
            await db
              .update(botsTable)
              .set({ status: liveStatus })
              .where(eq(botsTable.id, bot.id));
            console.log(
              `[CLEANUP] Bot ${bot.id} status: ${bot.status} \u2192 ${liveStatus}`,
            );
          }
        } catch (err) {
          console.warn(
            `[CLEANUP] Could not reconcile bot ${bot.id}:`,
            err?.message ?? err,
          );
        }
      }),
    );

    const reconciled = results.filter((r) => r.status === "fulfilled").length;
    console.log(
      `[CLEANUP] Status reconciliation complete (${reconciled}/${runningBots.length} checked).`,
    );
    return results;
  };
}
