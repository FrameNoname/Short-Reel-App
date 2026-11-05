const FILM_SELECT = `
  SELECT f.id, f.title, f.synopsis, f.poster_url, f.genre_id, f.ai_tool_id,
         g.name AS genre, t.name AS ai_tool, f.prompt_credit, f.is_ai_generated, f.status,
         f.catalog_drama_id, f.created_at,
         (SELECT COUNT(*) FROM episodes e WHERE e.film_id = f.id) AS episode_count,
         (SELECT COUNT(*) FROM episodes e WHERE e.film_id = f.id AND e.is_free = 1) AS free_count,
         (SELECT COALESCE(SUM(e.duration_sec), 0) FROM episodes e WHERE e.film_id = f.id) AS total_duration_sec,
         (SELECT COUNT(*) FROM likes l WHERE l.film_id = f.id) AS like_count,
         (SELECT COUNT(*) FROM comments c WHERE c.film_id = f.id) AS comment_count
    FROM films f
    JOIN genres g ON g.id = f.genre_id
    JOIN ai_tools t ON t.id = f.ai_tool_id`;

const SORT_SQL = {
  latest: 'created_at DESC, id DESC',
  popular: 'like_count DESC, id DESC',
  title: 'title ASC',
};

exports.SORTS = Object.keys(SORT_SQL);

// Catalog series are listed by the app from Series Jeen itself, never here.
exports.search = async (pool, { status, q, sort, limit, offset }) => {
  const where = ['catalog_drama_id IS NULL'];
  const params = [];
  if (status) {
    where.push('status = ?');
    params.push(status);
  }
  if (q) {
    where.push('title LIKE ?');
    params.push(`%${q}%`);
  }
  const clause = `WHERE ${where.join(' AND ')}`;
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

exports.serialize = (row) => ({
  id: row.id,
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
  episode_count: Number(row.episode_count),
  free_count: Number(row.free_count),
  total_duration_sec: Number(row.total_duration_sec),
  like_count: Number(row.like_count),
  comment_count: Number(row.comment_count),
  created_at: row.created_at,
});
