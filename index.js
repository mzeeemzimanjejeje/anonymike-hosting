// Pterodactyl entry point — `node index.js` runs from /home/container
// Delegates to the actual server bundle in artifacts/api-server/
import('./artifacts/api-server/index.js').catch(err => {
  console.error(err);
  process.exit(1);
});
