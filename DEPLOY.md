# ANONYMIKETECH — VPS Deployment Guide

## Requirements
- Node.js 20+
- PostgreSQL 14+
- A Pterodactyl panel with:
  - An **Application API key** (`ptla_...`) from Admin → Application API
  - A **Client API key** (`ptlc_...`) from Account → API Credentials

---

## 1. Pull the code

```bash
git clone https://github.com/mzeeemzimanjejeje/anonymike-hosting.git
cd anonymike-hosting
```

## 2. Install dependencies

```bash
cd artifacts/api-server
npm install
```

## 3. Set up environment variables

```bash
cp .env.example .env
nano .env   # fill in all values
```

Key variables (required):

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `SESSION_SECRET` | Random 32+ char string (use `openssl rand -hex 32`) |
| `PTERODACTYL_URL` | Your panel URL e.g. `https://panel.example.com` |
| `PTERODACTYL_API_KEY` | Application key (`ptla_...`) from Admin → Application API |
| `PTERODACTYL_CLIENT_KEY` | Client key (`ptlc_...`) from Account → API Credentials |
| `ADMIN_EMAILS` | Comma-separated admin email addresses |
| `PORT` | Port to listen on (default 3000) |

## 4. Apply the database schema

```bash
# From the artifacts/api-server directory:
node -e "
const { Client } = require('pg');
const fs = require('fs');
const client = new Client({ connectionString: process.env.DATABASE_URL });
client.connect().then(() => client.query(fs.readFileSync('schema.sql','utf8'))).then(() => { console.log('Schema applied'); client.end(); });
"
```

## 5. Start the server

**Direct (for testing):**
```bash
node index.js
```

**With PM2 (recommended for production):**
```bash
npm install -g pm2
pm2 start index.js --name anonymiketech --env production
pm2 save
pm2 startup
```

## 6. Verify

```bash
curl http://localhost:3000/api/healthz
# → {"status":"ok"}

curl http://localhost:3000/api/maintenance-status
# → {"maintenance":false}
```

---

## Updating

```bash
git pull
# restart:
pm2 restart anonymiketech
# or:
node index.js
```

---

## Pterodactyl Key Setup

1. **Application key** — Panel → Admin → Application API → Create new
2. **Client key** — Panel → Account (top right) → API Credentials → Create API Key
   - Grant access to all servers the admin account owns
   - This key handles power signals, file writes, and resource monitoring

Both keys are required. Using only the Application key will break start/stop/restart.

---

## Nginx reverse proxy (optional)

```nginx
server {
    listen 80;
    server_name your-domain.com;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```
