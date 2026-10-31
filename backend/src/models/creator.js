// What the film owner earns from an unlock. An admin's own films pay the whole
// price to the admin, so their share column is the admin one.
const OWNER_SHARE = `CASE WHEN u.role = 'admin' THEN ue.admin_share ELSE ue.creator_share END`;

exports.earnings = async (pool, ownerId) => {
  const [perFilm] = await pool.query(
    `SELECT f.id AS film_id, f.title, f.status, COUNT(ue.id) AS unlock_count,
            COALESCE(SUM(ue.coins_spent), 0) AS coins_spent,
            COALESCE(SUM(${OWNER_SHARE}), 0) AS coins_earned
       FROM films f JOIN users u ON u.id = f.creator_id
       LEFT JOIN episodes e ON e.film_id = f.id
       LEFT JOIN unlocked_episodes ue ON ue.episode_id = e.id
      WHERE f.creator_id = ?
      GROUP BY f.id, f.title, f.status ORDER BY coins_earned DESC, f.id`,
    [ownerId],
  );
  const [recent] = await pool.query(
    `SELECT ue.id, ue.created_at, ue.coins_spent, ue.creator_share, ue.admin_share,
            ${OWNER_SHARE} AS coins_earned, f.id AS film_id, f.title AS film_title, e.episode_no
       FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
       JOIN users u ON u.id = f.creator_id
      WHERE f.creator_id = ? ORDER BY ue.id DESC LIMIT 20`,
    [ownerId],
  );
  const films = perFilm.map((r) => ({
    ...r,
    unlock_count: Number(r.unlock_count),
    coins_spent: Number(r.coins_spent),
    coins_earned: Number(r.coins_earned),
  }));
  return {
    unit: 'coins',
    coins_earned: films.reduce((sum, f) => sum + f.coins_earned, 0),
    coins_spent_by_viewers: films.reduce((sum, f) => sum + f.coins_spent, 0),
    unlock_count: films.reduce((sum, f) => sum + f.unlock_count, 0),
    films,
    recent_unlocks: recent,
  };
};

exports.filmIds = async (pool, ownerId) => {
  const [rows] = await pool.query('SELECT id FROM films WHERE creator_id = ?', [ownerId]);
  return rows.map((r) => r.id);
};
