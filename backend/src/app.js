const express = require('express');
const cors = require('cors');
const { pool } = require('./db');

const app = express();
const origins = (process.env.CORS_ORIGIN || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.disable('x-powered-by');
app.use(cors({
  origin(origin, callback) {
    if (!origin || origins.includes('*') || origins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin not allowed by CORS'));
  },
}));
app.use(express.json({ limit: '32kb' }));

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok', database: 'connected' });
  } catch (_error) {
    res.status(503).json({ status: 'error', database: 'unavailable' });
  }
});

app.get('/api/tasks', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, title, description, completed, created_at, updated_at FROM tasks ORDER BY created_at DESC, id DESC'
    );
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

app.post('/api/tasks', async (req, res, next) => {
  try {
    const { title, description = '' } = req.body || {};
    const validationError = validateTaskFields({ title, description });
    if (validationError) return res.status(400).json({ error: validationError });

    const { rows } = await pool.query(
      `INSERT INTO tasks (title, description)
       VALUES ($1, $2)
       RETURNING id, title, description, completed, created_at, updated_at`,
      [title.trim(), description.trim()]
    );
    res.status(201).json(rows[0]);
  } catch (error) {
    next(error);
  }
});

app.patch('/api/tasks/:id', async (req, res, next) => {
  try {
    const id = parseId(req.params.id);
    if (!id) return res.status(400).json({ error: 'Task ID must be a positive integer.' });

    const { rows: existingRows } = await pool.query(
      'SELECT id, title, description, completed FROM tasks WHERE id = $1', [id]
    );
    if (existingRows.length === 0) return res.status(404).json({ error: 'Task not found.' });

    const body = req.body || {};
    const allowed = ['title', 'description', 'completed'];
    const supplied = Object.keys(body);
    if (supplied.length === 0 || supplied.some((key) => !allowed.includes(key))) {
      return res.status(400).json({ error: 'Provide at least one supported field: title, description, completed.' });
    }

    const current = existingRows[0];
    const title = Object.prototype.hasOwnProperty.call(body, 'title') ? body.title : current.title;
    const description = Object.prototype.hasOwnProperty.call(body, 'description') ? body.description : current.description;
    const completed = Object.prototype.hasOwnProperty.call(body, 'completed') ? body.completed : current.completed;
    const validationError = validateTaskFields({ title, description });
    if (validationError) return res.status(400).json({ error: validationError });
    if (typeof completed !== 'boolean') return res.status(400).json({ error: '`completed` must be a boolean.' });

    const { rows } = await pool.query(
      `UPDATE tasks
       SET title = $1, description = $2, completed = $3, updated_at = NOW()
       WHERE id = $4
       RETURNING id, title, description, completed, created_at, updated_at`,
      [title.trim(), description.trim(), completed, id]
    );
    res.json(rows[0]);
  } catch (error) {
    next(error);
  }
});

app.delete('/api/tasks/:id', async (req, res, next) => {
  try {
    const id = parseId(req.params.id);
    if (!id) return res.status(400).json({ error: 'Task ID must be a positive integer.' });
    const result = await pool.query('DELETE FROM tasks WHERE id = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Task not found.' });
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  if (error && error.message === 'Origin not allowed by CORS') {
    return res.status(403).json({ error: error.message });
  }
  console.error(error);
  return res.status(500).json({ error: 'Unexpected server error.' });
});

function parseId(value) {
  if (!/^\d+$/.test(String(value))) return null;
  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function validateTaskFields({ title, description }) {
  if (typeof title !== 'string' || title.trim().length === 0) {
    return '`title` is required and must be a non-empty string.';
  }
  if (title.trim().length > 120) return '`title` must be 120 characters or fewer.';
  if (typeof description !== 'string') return '`description` must be a string.';
  if (description.trim().length > 500) return '`description` must be 500 characters or fewer.';
  return null;
}

module.exports = app;
