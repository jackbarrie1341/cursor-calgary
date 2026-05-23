import { env } from "./config/env.js";
import { pool } from "./db/client.js";
import { app } from "./app.js";

const server = app.listen(env.PORT, () => {
  console.log(`Finance Buddy backend listening on http://localhost:${env.PORT}`);
});

async function shutdown() {
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
