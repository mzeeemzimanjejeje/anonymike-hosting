#!/bin/bash
# ANONYMIKETECH — startup script (auto-generated)
# Pterodactyl startup command: bash artifacts/api-server/start.sh

export DATABASE_URL="postgresql://postgres:password@helium/heliumdb?sslmode=disable"
export NEON_DATABASE_URL="postgresql://neondb_owner:npg_YBtI6ULyA5cP@ep-lively-feather-atdq7jna-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
export SESSION_SECRET="1lw7AgPiIUJd64IEZrN59Iih5shcNqGWRuMJk9NzAf5K/ejMpEYZeblVyxbFK+OcI6WseT4FP4fyHMZzT/kapQ=="
export PTERODACTYL_URL="apps.courtneytech.xyz"
export PTERODACTYL_API_KEY="ptla_Lc8SUEwKo2HL8nOrFIwPbnazSz02xoFTX6nGhgzXFYy"
export PTERODACTYL_CLIENT_KEY="ptlc_7POw4D6GuFv981xOr5OJwkuaCPXtgsw4E30257OSsQF"
export ADMIN_EMAILS="admin@anonymiketech.online"
export NODE_ENV="production"

cd "$(dirname "$0")"
npm install --omit=dev 2>/dev/null || npm install
node index.js
