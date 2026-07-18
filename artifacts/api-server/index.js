// ANONYMIKETECH — Entry point
// Supports both Replit and VPS/Pterodactyl deployments.
// Requires Node.js 20+
//
// Database routing:
//   Replit:  Set NEON_DATABASE_URL → app data goes to Neon, sessions stay on Replit's built-in DB
//   VPS:     Set DATABASE_URL → all data goes there.
//            Optionally set SESSION_DATABASE_URL to store sessions on a separate DB.

if (process.env.NEON_DATABASE_URL) {
  // Replit mode: split session storage from app data
  process.env.SESSION_DATABASE_URL = process.env.DATABASE_URL; // Replit's DB → sessions
  process.env.DATABASE_URL = process.env.NEON_DATABASE_URL;    // Neon → app data
}
// VPS mode: DATABASE_URL and SESSION_DATABASE_URL (optional) are set directly in the egg / .env

await import('./server.mjs');
