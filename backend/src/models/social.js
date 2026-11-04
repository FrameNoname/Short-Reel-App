const ApiError = require('../utils/ApiError');

exports.setLike = async (pool, userId, filmId, on) => {
  await pool.query(
    on
      ? 'INSERT IGNORE INTO likes (user_id, film_id) VALUES (?, ?)'
      : 'DELETE FROM likes WHERE user_id = ? AND film_id = ?',
    [userId, filmId],
  );
  const [[row]] = await pool.query('SELECT COUNT(*) AS n FROM likes WHERE film_id = ?', [filmId]);
  return row.n;
};

exports.setWatchlist = (pool, userId, filmId, on) =>
  pool.query(
    on
      ? 'INSERT IGNORE INTO watchlist (user_id, film_id) VALUES (?, ?)'
      : 'DELETE FROM watchlist WHERE user_id = ? AND film_id = ?',
    [userId, filmId],
  );

exports.listWatchlist = async (pool, userId) => {
  const [rows] = await pool.query(
    `SELECT film_id FROM watchlist w JOIN films f ON f.id = w.film_id
      WHERE w.user_id = ? AND f.status = 'approved'`,
    [userId],
  );
  return rows.map((r) => r.film_id);
};

exports.listComments = async (pool, filmId) => {
  const [rows] = await pool.query(
    `SELECT c.id, c.user_id, u.username, c.body, c.created_at
       FROM comments c JOIN users u ON u.id = c.user_id
      WHERE c.film_id = ? ORDER BY c.id DESC LIMIT 200`,
    [filmId],
  );
  return rows;
};

exports.addComment = async (pool, userId, filmId, body) => {
  const [result] = await pool.query(
    'INSERT INTO comments (user_id, film_id, body) VALUES (?, ?, ?)',
    [userId, filmId, body],
  );
  return result.insertId;
};

exports.removeComment = async (pool, user, commentId) => {
  const [rows] = await pool.query('SELECT user_id FROM comments WHERE id = ?', [commentId]);
  if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Comment not found');
  if (rows[0].user_id !== user.id && user.role !== 'admin') {
    throw new ApiError(403, 'FORBIDDEN', 'You can only delete your own comments');
  }
  await pool.query('DELETE FROM comments WHERE id = ?', [commentId]);
};

// Which of these films the viewer liked or saved.
exports.flags = async (pool, userId, films) => {
  if (films.length === 0) return { liked: new Set(), saved: new Set() };
  const ids = films.map((f) => f.id);
  const [[liked], [saved]] = await Promise.all([
    pool.query('SELECT film_id FROM likes WHERE user_id = ? AND film_id IN (?)', [userId, ids]),
    pool.query('SELECT film_id FROM watchlist WHERE user_id = ? AND film_id IN (?)', [userId, ids]),
  ]);
  return {
    liked: new Set(liked.map((r) => r.film_id)),
    saved: new Set(saved.map((r) => r.film_id)),
  };
};
