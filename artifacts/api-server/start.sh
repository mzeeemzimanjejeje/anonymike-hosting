#!/bin/bash
# ============================================================
#  ANONYMIKETECH — Full self-contained startup
#  Pterodactyl startup command: bash artifacts/api-server/start.sh
#  Does everything: env → pull → deps → schema → start
# ============================================================

# ── Environment Variables ────────────────────────────────────
export DATABASE_URL="postgresql://postgres:password@helium/heliumdb?sslmode=disable"
export NEON_DATABASE_URL="postgresql://neondb_owner:npg_YBtI6ULyA5cP@ep-lively-feather-atdq7jna-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
export SESSION_SECRET="1lw7AgPiIUJd64IEZrN59Iih5shcNqGWRuMJk9NzAf5K/ejMpEYZeblVyxbFK+OcI6WseT4FP4fyHMZzT/kapQ=="
export PTERODACTYL_URL="apps.courtneytech.xyz"
export PTERODACTYL_API_KEY="ptla_Lc8SUEwKo2HL8nOrFIwPbnazSz02xoFTX6nGhgzXFYy"
export PTERODACTYL_CLIENT_KEY="ptlc_7POw4D6GuFv981xOr5OJwkuaCPXtgsw4E30257OSsQF"
export ADMIN_EMAILS="admin@anonymiketech.online"
export NODE_ENV="production"

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
