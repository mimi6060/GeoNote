const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'geonote',
  user: process.env.DB_USER || 'geonote',
  password: process.env.DB_PASSWORD || 'geonote',
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Auto-create feedback table if missing
pool.query(`
  CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  )
`).catch(err => console.error('Feedback table creation:', err.message));

// ============================================
// GET /api/messages/nearby
// ============================================
app.get('/api/messages/nearby', async (req, res) => {
  const lat = parseFloat(req.query.latitude) || 48.8566;
  const lng = parseFloat(req.query.longitude) || 2.3522;
  const radius = parseInt(req.query.radius, 10) || 500;
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
  const hashtag = req.query.hashtag || null;

  try {
    let result = await pool.query(
      'SELECT * FROM get_nearby_messages($1, $2, $3, $4)',
      [lat, lng, radius, limit]
    );

    let messages = result.rows;

    if (hashtag) {
      const tag = hashtag.replace(/^#/, '').toLowerCase();
      messages = messages.filter(m =>
        m.hashtags && m.hashtags.some(h => h.toLowerCase().includes(tag))
      );
    }

    const sort = req.query.sort || 'distance';
    if (sort === 'recent') {
      messages.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    } else if (sort === 'popular') {
      messages.sort((a, b) => b.likes_count - a.likes_count);
    }

    res.json({ messages, count: messages.length, center: { latitude: lat, longitude: lng }, radius });
  } catch (err) {
    console.error('Error fetching nearby messages:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/messages (all public, for large radius fallback)
// ============================================
app.get('/api/messages', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT m.*, u.username
      FROM messages m
      JOIN users u ON m.user_id = u.id
      WHERE m.visibility = 'public'
      ORDER BY m.created_at DESC
      LIMIT 100
    `);
    res.json({ messages: result.rows });
  } catch (err) {
    console.error('Error fetching messages:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// POST /api/messages
// ============================================
app.post('/api/messages', async (req, res) => {
  const { content, latitude, longitude, visibility, user_id } = req.body;

  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Le message ne peut pas etre vide' });
  }
  if (content.length > 500) {
    return res.status(400).json({ error: '500 caracteres maximum' });
  }
  if (latitude == null || longitude == null) {
    return res.status(400).json({ error: 'Position GPS requise' });
  }

  const hashtags = (content.match(/#([a-zA-Z0-9_]+)/g) || [])
    .map(t => t.slice(1).toLowerCase());

  // Default user for MVP (alice_explore)
  const uid = user_id || 'a1111111-1111-1111-1111-111111111111';
  const vis = ['public', 'friends', 'private'].includes(visibility) ? visibility : 'public';

  try {
    const result = await pool.query(`
      INSERT INTO messages (user_id, content, latitude, longitude, visibility, hashtags)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id, created_at
    `, [uid, content.trim(), latitude, longitude, vis, hashtags]);

    res.status(201).json({ message: 'Message publie', ...result.rows[0] });
  } catch (err) {
    console.error('Error creating message:', err);
    res.status(500).json({ error: 'Erreur lors de la creation' });
  }
});

// ============================================
// POST /api/interactions (like / comment)
// ============================================
app.post('/api/interactions', async (req, res) => {
  const { message_id, type, content, user_id } = req.body;

  if (!message_id || !['like', 'comment'].includes(type)) {
    return res.status(400).json({ error: 'Parametres invalides' });
  }
  if (type === 'comment' && (!content || !content.trim())) {
    return res.status(400).json({ error: 'Commentaire requis' });
  }

  // Default user for MVP (bob_runner)
  const uid = user_id || 'b2222222-2222-2222-2222-222222222222';

  try {
    if (type === 'like') {
      // Toggle like
      const existing = await pool.query(
        'SELECT id FROM interactions WHERE message_id = $1 AND user_id = $2 AND type = $3',
        [message_id, uid, 'like']
      );

      if (existing.rows.length > 0) {
        await pool.query('DELETE FROM interactions WHERE id = $1', [existing.rows[0].id]);
      } else {
        await pool.query(
          'INSERT INTO interactions (message_id, user_id, type) VALUES ($1, $2, $3)',
          [message_id, uid, 'like']
        );
      }

      const countResult = await pool.query(
        'SELECT likes_count FROM messages WHERE id = $1', [message_id]
      );
      const liked = existing.rows.length === 0;
      res.json({ liked, likes_count: countResult.rows[0]?.likes_count || 0 });
    } else {
      await pool.query(
        'INSERT INTO interactions (message_id, user_id, type, content) VALUES ($1, $2, $3, $4)',
        [message_id, uid, 'comment', content.trim()]
      );
      res.status(201).json({ message: 'Commentaire ajoute' });
    }
  } catch (err) {
    console.error('Error with interaction:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/interactions?message_id=&type=comment
// ============================================
app.get('/api/interactions', async (req, res) => {
  const { message_id, type } = req.query;

  if (!message_id) {
    return res.status(400).json({ error: 'message_id requis' });
  }

  try {
    let query = `
      SELECT i.id, i.type, i.content, i.created_at, u.username
      FROM interactions i
      JOIN users u ON i.user_id = u.id
      WHERE i.message_id = $1
    `;
    const params = [message_id];

    if (type) {
      query += ' AND i.type = $2';
      params.push(type);
    }

    query += ' ORDER BY i.created_at ASC';

    const result = await pool.query(query, params);
    res.json({ comments: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Error fetching interactions:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/users/:id/messages
// ============================================
app.get('/api/users/:id/messages', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT m.*, u.username
      FROM messages m
      JOIN users u ON m.user_id = u.id
      WHERE m.user_id = $1
      ORDER BY m.created_at DESC
    `, [req.params.id]);
    res.json({ messages: result.rows });
  } catch (err) {
    console.error('Error fetching user messages:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// DELETE /api/messages/:id
// ============================================
app.delete('/api/messages/:id', async (req, res) => {
  const { user_id } = req.body || {};

  try {
    const msg = await pool.query(
      'SELECT user_id FROM messages WHERE id = $1', [req.params.id]
    );
    if (msg.rows.length === 0) {
      return res.status(404).json({ error: 'Message non trouve' });
    }
    if (user_id && msg.rows[0].user_id !== user_id) {
      return res.status(403).json({ error: 'Non autorise' });
    }
    await pool.query('DELETE FROM messages WHERE id = $1', [req.params.id]);
    res.json({ message: 'Message supprime' });
  } catch (err) {
    console.error('Error deleting message:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/stats
// ============================================
app.get('/api/stats', async (req, res) => {
  try {
    const [msgCount, userCount, betaCount] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM messages'),
      pool.query('SELECT COUNT(*) FROM users'),
      pool.query('SELECT COUNT(*) FROM beta_signups'),
    ]);
    res.json({
      messages: parseInt(msgCount.rows[0].count),
      users: parseInt(userCount.rows[0].count),
      beta_signups: parseInt(betaCount.rows[0].count),
    });
  } catch (err) {
    console.error('Error fetching stats:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// POST /api/beta-signup
// ============================================
app.post('/api/beta-signup', async (req, res) => {
  const { email } = req.body;

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Email invalide' });
  }

  try {
    await pool.query('INSERT INTO beta_signups (email) VALUES ($1)', [email]);
    res.status(201).json({ message: 'Inscription reussie !' });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Email deja enregistre' });
    }
    console.error('Error beta signup:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/admin/dashboard
// ============================================
app.get('/api/admin/dashboard', async (req, res) => {
  try {
    const [stats, recent, top, beta, interactions] = await Promise.all([
      pool.query(`SELECT
        (SELECT COUNT(*) FROM messages) AS messages,
        (SELECT COUNT(*) FROM users) AS users,
        (SELECT COUNT(*) FROM beta_signups) AS beta_signups,
        (SELECT COUNT(*) FROM interactions) AS interactions
      `),
      pool.query(`
        SELECT m.*, u.username FROM messages m
        JOIN users u ON m.user_id = u.id
        ORDER BY m.created_at DESC LIMIT 10
      `),
      pool.query(`
        SELECT m.*, u.username FROM messages m
        JOIN users u ON m.user_id = u.id
        WHERE m.visibility = 'public'
        ORDER BY m.likes_count DESC LIMIT 10
      `),
      pool.query('SELECT email, created_at FROM beta_signups ORDER BY created_at DESC'),
      pool.query('SELECT COUNT(*) FROM interactions'),
    ]);
    res.json({
      stats: {
        messages: parseInt(stats.rows[0].messages),
        users: parseInt(stats.rows[0].users),
        beta_signups: parseInt(stats.rows[0].beta_signups),
        interactions: parseInt(stats.rows[0].interactions),
      },
      recent_messages: recent.rows,
      top_messages: top.rows,
      beta_signups: beta.rows,
    });
  } catch (err) {
    console.error('Error dashboard:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET/POST /api/feedback
// ============================================
app.post('/api/feedback', async (req, res) => {
  const { content } = req.body;
  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Feedback vide' });
  }
  try {
    await pool.query(
      'INSERT INTO feedback (content) VALUES ($1)', [content.trim()]
    );
    res.status(201).json({ message: 'Feedback enregistre' });
  } catch (err) {
    console.error('Error feedback:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

app.get('/api/feedback', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM feedback ORDER BY created_at DESC LIMIT 50'
    );
    res.json({ feedbacks: result.rows });
  } catch (err) {
    console.error('Error fetching feedback:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// GET /api/admin/export/:type
// ============================================
app.get('/api/admin/export/:type', async (req, res) => {
  try {
    let result;
    switch (req.params.type) {
      case 'messages':
        result = await pool.query(`
          SELECT m.*, u.username FROM messages m
          JOIN users u ON m.user_id = u.id ORDER BY m.created_at DESC
        `);
        break;
      case 'beta':
        result = await pool.query('SELECT * FROM beta_signups ORDER BY created_at DESC');
        break;
      case 'feedback':
        result = await pool.query('SELECT * FROM feedback ORDER BY created_at DESC');
        break;
      default:
        return res.status(400).json({ error: 'Type invalide' });
    }
    res.json({ data: result.rows, count: result.rows.length, exported_at: new Date() });
  } catch (err) {
    console.error('Error export:', err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// ============================================
// Health check
// ============================================
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected' });
  } catch {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

// Page routing
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'landing.html'));
});

app.get('/map', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/profile', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'profile.html'));
});

app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Fallback
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'landing.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`GeoNote API running on http://localhost:${PORT}`);
});
