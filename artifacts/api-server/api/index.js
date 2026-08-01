// Vercel serverless entry point for Courtney Hosting API
// Vercel calls this handler directly for every request.
// server.mjs skips app.listen() when process.env.VERCEL is set.

import app from '../server.mjs';

export default app;
