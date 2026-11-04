const FILM_SELECT = `
  SELECT f.id, f.creator_id, f.title, f.synopsis, f.poster_url, f.genre_id, f.ai_tool_id,
         g.name AS genre, t.name AS ai_tool, f.prompt_credit, f.is_ai_generated, f.status,
         f.review_note, f.reviewed_at, f.created_at,
         u.username AS creator_username, COALESCE(u.display_name, u.username) AS creator_name,
         u.role AS creator_role,
         (SELECT COUNT(*) FROM episodes e WHERE e.film_id = f.id) AS episode_count,
         (SELECT COUNT(*) FROM episodes e WHERE e.film_id = f.id AND e.is_free = 1) AS free_count,
         (SELECT COALESCE(SUM(e.duration_sec), 0) FROM episodes e WHERE e.film_id = f.id) AS total_duration_sec,
         (SELECT COUNT(*) FROM follows fo WHERE fo.creator_id = f.creator_id) AS creator_followers,
         (SELECT COUNT(*) FROM likes l WHERE l.film_id = f.id) AS like_count,
         (SELECT COUNT(*) FROM comments c WHERE c.film_id = f.id) AS comment_count
    FROM films f
    JOIN genres g ON g.id = f.genre_id
    JOIN ai_tools t ON t.id = f.ai_tool_id
    JOIN users u ON u.id = f.creator_id`;

const SORT_SQL = {
  latest: 'created_at DESC, id DESC',
  popular: 'like_count DESC, id DESC',
  title: 'title ASC',
};

exports.SORTS = Object.keys(SORT_SQL);

exports.search = async (
  pool,
  { status, creatorId, q, sort, limit, offset },
) => {
  const where = [];
  const params = [];
  if (status) {
    where.push('status = ?');
    params.push(status);
  }
  if (creatorId) {
    where.push('creator_id = ?');
    params.push(creatorId);
  }
  if (q) {
    where.push('(title LIKE ? OR creator_name LIKE ?)');
    params.push(`%${q}%`, `%${q}%`);
  }
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const [rows] = await pool.query(
    `SELECT * FROM (${FILM_SELECT}) films ${clause} ORDER BY ${SORT_SQL[sort] ?? SORT_SQL.latest} LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );
  return rows;
};

exports.findById = async (db, id) => {
  const [rows] = await db.query(`${FILM_SELECT} WHERE f.id = ?`, [id]);
  return rows[0];
};

exports.lookups = async (pool) => {
  const [[genres], [aiTools]] = await Promise.all([
    pool.query('SELECT id, name FROM genres ORDER BY id'),
    pool.query('SELECT id, name FROM ai_tools ORDER BY id'),
  ]);
  return { genres, ai_tools: aiTools };
};

exports.lookupId = async (pool, table, name) => {
  const [rows] = await pool.query(`SELECT id FROM ${table} WHERE name = ?`, [name]);
  return rows[0]?.id;
};

exports.create = async (pool, f) => {
  const [result] = await pool.query(
    `INSERT INTO films (creator_id, title, synopsis, genre_id, ai_tool_id, prompt_credit, is_ai_generated, status)
     VALUES (?, ?, ?, ?, ?, ?, 1, 'pending')`,
    [f.creatorId, f.title, f.synopsis ?? null, f.genreId, f.aiToolId, f.promptCredit ?? null],
  );
  return result.insertId;
};

exports.update = (db, id, f) =>
  db.query(
    `UPDATE films SET title = ?, synopsis = ?, genre_id = ?, ai_tool_id = ?, prompt_credit = ? WHERE id = ?`,
    [f.title, f.synopsis ?? null, f.genreId, f.aiToolId, f.promptCredit ?? null, id],
  );

// Content changed by a non-admin: an approved or rejected film is reviewed again.
exports.sendBackToReview = (db, id) =>
  db.query(
    `UPDATE films SET status = 'pending', review_note = NULL, reviewed_by = NULL, reviewed_at = NULL
      WHERE id = ? AND status IN ('approved', 'rejected')`,
    [id],
  );

exports.remove = (db, id) => db.query('DELETE FROM films WHERE id = ?', [id]);

exports.purchaseCount = async (db, filmId) => {
  const [[row]] = await db.query(
    `SELECT COUNT(*) AS n FROM unlocked_episodes ue JOIN episodes e ON e.id = ue.episode_id WHERE e.film_id = ?`,
    [filmId],
  );
  return row.n;
};

exports.setReview = (db, id, { status, note, adminId }) =>
  db.query(
    'UPDATE films SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = NOW() WHERE id = ?',
    [status, note ?? null, adminId, id],
  );

exports.serialize = (row, { includePrivate = false } = {}) => ({
  id: row.id,
  creator_id: row.creator_id,
  creator: {
    id: row.creator_id,
    username: row.creator_username,
    name: row.creator_name,
    role: row.creator_role,
    follower_count: Number(row.creator_followers),
  },
  title: row.title,
  synopsis: row.synopsis,
  poster_url: row.poster_url,
  genre_id: row.genre_id,
  genre: row.genre,
  ai_tool_id: row.ai_tool_id,
  ai_tool: row.ai_tool,
  prompt_credit: row.prompt_credit,
  is_ai_generated: Boolean(row.is_ai_generated),
  status: row.status,
  review_note: includePrivate ? row.review_note : undefined,
  episode_count: Number(row.episode_count),
  free_count: Number(row.free_count),
  total_duration_sec: Number(row.total_duration_sec),
  like_count: Number(row.like_count),
  comment_count: Number(row.comment_count),
  created_at: row.created_at,
});
