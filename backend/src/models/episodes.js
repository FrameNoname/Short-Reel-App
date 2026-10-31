const EPISODE_COLUMNS =
  'e.id, e.film_id, e.episode_no, e.title, e.video_path, e.duration_sec, e.is_free, e.price_coins';

exports.listByFilm = async (db, filmId) => {
  const [rows] = await db.query(
    `SELECT ${EPISODE_COLUMNS} FROM episodes e WHERE e.film_id = ? ORDER BY e.episode_no`,
    [filmId],
  );
  return rows;
};

// Joins the film so a caller can check ownership and review status in one read.
exports.findWithFilm = async (db, id) => {
  const [rows] = await db.query(
    `SELECT ${EPISODE_COLUMNS}, f.creator_id, f.status AS film_status, f.title AS film_title
       FROM episodes e JOIN films f ON f.id = e.film_id WHERE e.id = ?`,
    [id],
  );
  return rows[0];
};

exports.nextNumber = async (db, filmId) => {
  const [[row]] = await db.query(
    'SELECT COALESCE(MAX(episode_no), 0) + 1 AS n FROM episodes WHERE film_id = ?',
    [filmId],
  );
  return row.n;
};

exports.create = async (db, e) => {
  const [result] = await db.query(
    `INSERT INTO episodes (film_id, episode_no, title, video_path, duration_sec, is_free, price_coins)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [e.filmId, e.episodeNo, e.title ?? null, e.videoPath, e.durationSec, e.isFree ? 1 : 0, e.priceCoins],
  );
  return result.insertId;
};

exports.update = (db, id, { title, isFree, priceCoins }) =>
  db.query('UPDATE episodes SET title = ?, is_free = ?, price_coins = ? WHERE id = ?', [
    title,
    isFree ? 1 : 0,
    priceCoins,
    id,
  ]);

exports.remove = (db, id) => db.query('DELETE FROM episodes WHERE id = ?', [id]);

exports.unlockCount = async (db, episodeId) => {
  const [[row]] = await db.query('SELECT COUNT(*) AS n FROM unlocked_episodes WHERE episode_id = ?', [
    episodeId,
  ]);
  return row.n;
};

// Several episodes may point at one demo clip; a file goes only when none does.
exports.pathInUse = async (db, videoPath) => {
  const [[row]] = await db.query('SELECT COUNT(*) AS n FROM episodes WHERE video_path = ?', [
    videoPath,
  ]);
  return row.n > 0;
};

exports.videoPathsOfFilm = async (db, filmId) => {
  const [rows] = await db.query('SELECT video_path FROM episodes WHERE film_id = ?', [filmId]);
  return rows.map((r) => r.video_path);
};

exports.serialize = (row, access) => ({
  id: row.id,
  film_id: row.film_id,
  episode_no: row.episode_no,
  title: row.title,
  duration_sec: row.duration_sec,
  is_free: Boolean(row.is_free),
  price_coins: row.price_coins,
  access,
});
