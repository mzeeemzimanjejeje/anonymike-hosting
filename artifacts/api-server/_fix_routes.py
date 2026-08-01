#!/usr/bin/env python3
"""Fix truncated server.mjs injection caused by $' replacement pattern."""
import sys

TAIL = r"""// src/index.ts
var rawPort = process.env["SERVER_PORT"] ?? process.env["PORT"] ?? "3000";
var port = Number(rawPort);
if (Number.isNaN(port) || port <= 0) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}
app_default.listen(port, (err) => {
  if (err) {
    logger.error({ err }, "Error listening on port");
    process.exit(1);
  }
  logger.info({ port }, "Server listening");
});
"""

REMAINING_ROUTES = '''
    if (status) { params.push(status); where += ' AND s.status=$' + params.length; }
    if (search) { params.push('%' + search + '%'); where += ' AND (s.subdomain ILIKE $' + params.length + ' OR u.email ILIKE $' + params.length + ')'; }
    params.push(Number(limit)); params.push(offset);
    try {
      const r = await pool.query('SELECT s.*,u.email as owner_email,u.first_name as owner_name FROM subdomains s JOIN users u ON u.id=s.user_id ' + where + ' ORDER BY s.created_at DESC LIMIT $' + (params.length-1) + ' OFFSET $' + params.length, params);
      const cnt = await pool.query('SELECT COUNT(*) FROM subdomains s JOIN users u ON u.id=s.user_id ' + where, params.slice(0,-2));
      res.json({ subdomains: r.rows, total: Number(cnt.rows[0].count) });
    } catch (e) { logger.error({ err: e }, 'admin get subdomains'); res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.put('/:id/suspend', adminOnly, async (req, res) => {
    try {
      const r = await pool.query("UPDATE subdomains SET status='suspended',suspended_at=NOW(),suspended_reason=$1,updated_at=NOW() WHERE id=$2 RETURNING *", [req.body.reason || null, req.params.id]);
      if (!r.rows.length) return res.status(404).json({ error: 'Not found' });
      await createNotification(r.rows[0].user_id, 'warning', '\u26a0\ufe0f Subdomain Suspended', r.rows[0].full_domain + ' has been suspended.');
      res.json({ success: true, subdomain: r.rows[0] });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.put('/:id/restore', adminOnly, async (req, res) => {
    try {
      const r = await pool.query("UPDATE subdomains SET status='active',suspended_at=NULL,suspended_reason=NULL,updated_at=NOW() WHERE id=$1 RETURNING *", [req.params.id]);
      if (!r.rows.length) return res.status(404).json({ error: 'Not found' });
      await createNotification(r.rows[0].user_id, 'success', '\u2705 Subdomain Restored', r.rows[0].full_domain + ' has been restored.');
      res.json({ success: true, subdomain: r.rows[0] });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.delete('/:id', adminOnly, async (req, res) => {
    try {
      const sdQ = await pool.query('SELECT * FROM subdomains WHERE id=$1', [req.params.id]);
      if (!sdQ.rows.length) return res.status(404).json({ error: 'Not found' });
      const sd = sdQ.rows[0];
      if (sd.cloudflare_record_id) await cfDeleteRecord(sd.cloudflare_record_id);
      await pool.query('DELETE FROM subdomains WHERE id=$1', [sd.id]);
      res.json({ success: true });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.put('/:id/force-renew', adminOnly, async (req, res) => {
    try {
      const sdQ = await pool.query('SELECT * FROM subdomains WHERE id=$1', [req.params.id]);
      if (!sdQ.rows.length) return res.status(404).json({ error: 'Not found' });
      const sd = sdQ.rows[0];
      const ne = new Date(Math.max(Date.now(), new Date(sd.expires_at).getTime()));
      ne.setFullYear(ne.getFullYear() + 1);
      const r = await pool.query("UPDATE subdomains SET expires_at=$1,renewal_reminder_sent=false,status='active',updated_at=NOW() WHERE id=$2 RETURNING *", [ne, sd.id]);
      await createNotification(sd.user_id, 'success', '\u2705 Subdomain Renewed', 'Admin renewed ' + sd.full_domain + ' until ' + ne.toLocaleDateString());
      res.json({ success: true, subdomain: r.rows[0] });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.get('/pricing', adminOnly, async (_req, res) => {
    try {
      const p = await pool.query('SELECT * FROM subdomain_pricing ORDER BY tier,kes_per_year');
      const pm = await pool.query('SELECT * FROM premium_subdomains ORDER BY kes_per_year DESC');
      const pc = await pool.query('SELECT * FROM promo_codes ORDER BY created_at DESC');
      res.json({ pricing: p.rows, premium: pm.rows, promo_codes: pc.rows });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.put('/pricing/:id', adminOnly, async (req, res) => {
    const { kes_per_year, coins_per_year, description, active } = req.body;
    try {
      const r = await pool.query('UPDATE subdomain_pricing SET kes_per_year=$1,coins_per_year=$2,description=$3,active=$4,updated_at=NOW() WHERE id=$5 RETURNING *', [kes_per_year, coins_per_year || kes_per_year * 10, description, active !== false, req.params.id]);
      if (!r.rows.length) return res.status(404).json({ error: 'Not found' });
      res.json({ success: true, pricing: r.rows[0] });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.post('/premium', adminOnly, async (req, res) => {
    const { name, kes_per_year } = req.body;
    if (!name) return res.status(400).json({ error: 'Name required' });
    try {
      const r = await pool.query('INSERT INTO premium_subdomains (name,kes_per_year) VALUES ($1,$2) ON CONFLICT (name) DO UPDATE SET kes_per_year=$2 RETURNING *', [name.toLowerCase().trim(), kes_per_year || 500]);
      res.status(201).json({ success: true, premium: r.rows[0] });
    } catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.delete('/premium/:name', adminOnly, async (req, res) => {
    try { await pool.query('DELETE FROM premium_subdomains WHERE name=$1', [req.params.name]); res.json({ success: true }); }
    catch { res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.post('/promo-codes', adminOnly, async (req, res) => {
    const { code, description, discount_type = 'percent', discount_value, max_uses, valid_until } = req.body;
    if (!code || !discount_value) return res.status(400).json({ error: 'Code and discount_value required' });
    try {
      const r = await pool.query('INSERT INTO promo_codes (code,description,discount_type,discount_value,max_uses,valid_until) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *', [code.toUpperCase().trim(), description, discount_type, discount_value, max_uses || null, valid_until || null]);
      res.status(201).json({ success: true, promo_code: r.rows[0] });
    } catch (e) { if (e.code === '23505') return res.status(409).json({ error: 'Code already exists' }); res.status(500).json({ error: 'Failed' }); }
  });

  adminSdRouter.delete('/promo-codes/:id', adminOnly, async (req, res) => {
    try { await pool.query('DELETE FROM promo_codes WHERE id=$1', [req.params.id]); res.json({ success: true }); }
    catch { res.status(500).json({ error: 'Failed' }); }
  });

  // ---- subdomain expiry maintenance ----
  async function runSubdomainMaint() {
    try {
      const exp = await pool.query("UPDATE subdomains SET status='expired',updated_at=NOW() WHERE status='active' AND expires_at<NOW() RETURNING id,user_id,full_domain");
      for (const sd of exp.rows) { try { await createNotification(sd.user_id,'error','\u274c Subdomain Expired',sd.full_domain+' has expired. Renew to restore access.'); } catch {} }
      const rem = await pool.query("UPDATE subdomains SET renewal_reminder_sent=true,updated_at=NOW() WHERE status='active' AND renewal_reminder_sent=false AND expires_at BETWEEN NOW() AND NOW()+INTERVAL '7 days' RETURNING id,user_id,full_domain");
      for (const sd of rem.rows) { try { await createNotification(sd.user_id,'warning','\u23f0 Subdomain Expiring Soon',sd.full_domain+' expires in less than 7 days. Please renew!'); } catch {} }
      if (exp.rows.length || rem.rows.length) logger.info({ expired: exp.rows.length, reminders: rem.rows.length }, '[SUBDOMAIN] Maintenance');
    } catch (e) { logger.error({ err: e }, '[SUBDOMAIN] Maintenance error'); }
  }
  setInterval(() => runSubdomainMaint().catch(()=>{}), 6 * 60 * 60 * 1000);
  runSubdomainMaint().catch(() => {});

  // ---- mount routers ----
  app.use('/api/subdomains', sdRouter);
  app.use('/api/admin/subdomains', adminSdRouter);

  logger.info('[SUBDOMAINS] Subdomain marketplace routes mounted');
})();

// robots.txt
app.get('/robots.txt', (_req, res) => {
  res.type('text/plain').send(
    'User-agent: *\nAllow: /\nDisallow: /dashboard\nDisallow: /admin\nDisallow: /api/\n\nSitemap: https://courtneytech.xyz/sitemap.xml'
  );
});

// sitemap.xml
app.get('/sitemap.xml', (_req, res) => {
  const host = 'https://courtneytech.xyz';
  const now = new Date().toISOString().split('T')[0];
  res.type('application/xml').send(
    '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>' + host + '</loc><lastmod>' + now + '</lastmod><changefreq>weekly</changefreq><priority>1.0</priority></url>\n  <url><loc>' + host + '/subdomains</loc><lastmod>' + now + '</lastmod><changefreq>weekly</changefreq><priority>0.9</priority></url>\n</urlset>'
  );
});

if (process.env.SERVE_STATIC === "true") {
  const __dirname2 = path.dirname(fileURLToPath(import.meta.url));
  const publicDir = path.resolve(__dirname2, "./public");
  app.use(import_express11.default.static(publicDir));
  // Subdomain marketplace (before catch-all)
  app.get("/subdomains", (_req, res) => res.sendFile(path.join(publicDir, "subdomains.html")));
  app.get("/{*path}", (_req, res) => {
    res.sendFile(path.join(publicDir, "index.html"));
  });
  logger.info({ publicDir }, "Serving static frontend from disk");
}
var app_default = app;

'''

with open('server.mjs', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the truncation point: line containing the broken partial line
# We want to keep everything up to and including the line before line 63272 (0-indexed: 63271)
# Line 63271 (1-indexed) = index 63270 (0-indexed) contains:
#     let where = 'WHERE 1=1'; const params = [];
# Line 63272 (1-indexed) = index 63271 (0-indexed) contains the broken line

# Find the exact truncation point by searching for the truncated line marker
TRUNCATION_MARKER = "    if (status) { params.push(status); where += ' AND s.status="
TAIL_MARKER = "// src/index.ts"

truncate_at = None
tail_start = None

for i, line in enumerate(lines):
    if TRUNCATION_MARKER in line and truncate_at is None:
        truncate_at = i  # This is the line to replace (0-indexed)
    if line.strip() == TAIL_MARKER and truncate_at is not None and tail_start is None:
        tail_start = i

if truncate_at is None:
    print(f"ERROR: Could not find truncation marker")
    sys.exit(1)

if tail_start is None:
    print(f"ERROR: Could not find tail marker (// src/index.ts)")
    sys.exit(1)

print(f"Truncating at line {truncate_at + 1} (0-indexed: {truncate_at})")
print(f"Tail starts at line {tail_start + 1}")
print(f"Truncated content: {repr(lines[truncate_at][:80])}")

# Keep lines 0..truncate_at-1, then append REMAINING_ROUTES, then append from tail_start onwards
kept_lines = lines[:truncate_at]
tail_lines = lines[tail_start:]

with open('server.mjs', 'w', encoding='utf-8') as f:
    f.writelines(kept_lines)
    f.write(REMAINING_ROUTES)
    f.writelines(tail_lines)

# Verify
with open('server.mjs', 'r', encoding='utf-8') as f:
    final_lines = f.readlines()

print(f"Done. Total lines: {len(final_lines)}")
# Check key markers
content = ''.join(final_lines)
checks = [
    ('sdRouter', 'sdRouter defined'),
    ('adminSdRouter', 'adminSdRouter defined'),
    ('/api/subdomains', 'subdomain router mounted'),
    ('/api/admin/subdomains', 'admin router mounted'),
    ('robots.txt', 'robots.txt route'),
    ('sitemap.xml', 'sitemap.xml route'),
    ('/subdomains.html', 'subdomains page route'),
    ('var app_default = app', 'app_default'),
    ('Server listening', 'listen'),
]
for marker, desc in checks:
    found = marker in content
    print(f"  {'OK' if found else 'MISSING'}: {desc}")
