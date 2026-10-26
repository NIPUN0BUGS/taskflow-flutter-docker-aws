const app = require('./app');
const { pool, initializeDatabase } = require('./db');

const port = Number(process.env.PORT || 3000);

async function start() {
  try {
    await initializeDatabase();
    const server = app.listen(port, '0.0.0.0', () => {
      console.log(`TaskFlow API listening on port ${port}`);
    });

    const shutdown = (signal) => {
      console.log(`${signal} received; shutting down gracefully`);
      server.close(async () => {
        await pool.end();
        process.exit(0);
      });
      setTimeout(() => process.exit(1), 10000).unref();
    };
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  } catch (error) {
    console.error('Could not start TaskFlow API:', error);
    await pool.end().catch(() => {});
    process.exit(1);
  }
}

start();
