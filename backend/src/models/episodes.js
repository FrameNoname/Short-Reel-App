const EPISODE_COLUMNS =
  'e.id, e.film_id, e.episode_no, e.title, e.video_path, e.duration_sec, e.is_free, e.price_coins';

exports.listByFilm = async (db, filmId) => {
  const [rows] = await db.query(
    `SELECT ${EPISODE_COLUMNS} FROM episodes e WHERE e.film_id = ? ORDER BY e.episode_no`,
    [filmId],
  );
  return rows;
};

// Joins the film so a caller can check its review status in the same read.
exports.findWithFilm = async (db, id) => {
  const [rows] = await db.query(
    `SELECT ${EPISODE_COLUMNS}, f.status AS film_status, f.title AS film_title
       FROM episodes e JOIN films f ON f.id = e.film_id WHERE e.id = ?`,
    [id],
  );
  return rows[0];
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
