#!/bin/bash
# ============================================================
#  ANONYMIKETECH — Full self-contained startup
#  Pterodactyl startup command: bash artifacts/api-server/start.sh
#  Does everything: pull → deps → schema → start
#
#  All secrets (DATABASE_URL, NEON_DATABASE_URL, SESSION_SECRET,
#  PTERODACTYL_URL, PTERODACTYL_API_KEY, PTERODACTYL_CLIENT_KEY,
#  ADMIN_EMAILS) must be injected via environment variables —
#  never hardcode them here.
# ============================================================

# Fail fast if required secrets are missing
: "${DATABASE_URL:?DATABASE_URL must be set}"
: "${SESSION_SECRET:?SESSION_SECRET must be set}"

export NODE_ENV="${NODE_ENV:-production}"

# ── Pull latest code from GitHub ─────────────────────────────
echo "[1/4] Pulling latest code from GitHub..."
cd /home/container 2>/dev/null || cd "$(dirname "$0")/../.."
git pull origin main 2>/dev/null || git clone https://github.com/mzeeemzimanjejeje/anonymike-hosting.git . 2>/dev/null || true

# ── Install dependencies ──────────────────────────────────────
echo "[2/4] Installing dependencies..."
cd /home/container/artifacts/api-server 2>/dev/null || cd "$(dirname "$0")"
npm install --omit=dev --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund

# ── Apply database schema ─────────────────────────────────────
echo "[3/4] Applying database schema..."
node - <<'SCHEMA'
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');

async function applySchema(url, label) {
  if (!url) { console.log(`  [skip] ${label} — not configured`); return; }
  const client = new Client({ connectionString: url, ssl: url.includes('neon') ? { rejectUnauthorized: false } : false });
  try {
    await client.connect();
    await client.query(sql);
    console.log(`  [ok] ${label} schema applied`);
  } catch (err) {
    console.error(`  [warn] ${label}: ${err.message}`);
  } finally {
    await client.end().catch(() => {});
  }
}

(async () => {
  await applySchema(process.env.DATABASE_URL,      'Primary DB');
  await applySchema(process.env.NEON_DATABASE_URL, 'Neon DB');
})();
SCHEMA

# ── Start server ──────────────────────────────────────────────
echo "[4/4] Starting ANONYMIKETECH server..."
node index.js
