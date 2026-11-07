const ApiError = require('../utils/ApiError');

// Every coin spent on an unlock goes to the admin, who runs the catalogue.
exports.sales = async (pool) => {
  const [[coins]] = await pool.query(
    `SELECT COUNT(*) AS unlock_count, COALESCE(SUM(coins_spent), 0) AS coins_spent
       FROM unlocked_episodes`,
  );
  const [[topups]] = await pool.query(
    `SELECT COUNT(*) AS count, COALESCE(SUM(price_usd), 0) AS simulated_usd, COALESCE(SUM(amount), 0) AS coins_issued
       FROM coin_transactions WHERE type = 'topup'`,
  );
  const [perFilm] = await pool.query(
    `SELECT f.id AS film_id, f.title, COUNT(ue.id) AS unlock_count,
            COALESCE(SUM(ue.coins_spent), 0) AS coins_spent
       FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      GROUP BY f.id, f.title ORDER BY coins_spent DESC, f.id`,
  );
  const [recent] = await pool.query(
    `SELECT ue.id, ue.created_at, ue.coins_spent,
            buyer.username AS buyer, f.id AS film_id, f.title AS film_title, e.episode_no
       FROM unlocked_episodes ue
       JOIN users buyer ON buyer.id = ue.user_id
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      ORDER BY ue.id DESC LIMIT 20`,
  );
  const num = (row) => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, Number(v)]));
  return {
    // Coins and simulated dollars are different units and are never summed.
    coins: { unit: 'coins', ...num(coins) },
    simulated_payments: {
      unit: 'usd (simulated, no real money)',
      coin_topups: num(topups),
    },
    per_film: perFilm.map((row) => ({
      ...row,
      unlock_count: Number(row.unlock_count),
      coins_spent: Number(row.coins_spent),
    })),
    recent_unlocks: recent,
  };
};

// ---- content --------------------------------------------------------------

// The app's own films, taken-down ones included. Catalog series are listed by
// Series Jeen, so taking one down here would not hide it.
exports.listFilms = async (pool) => {
  const [rows] = await pool.query(
    `SELECT f.id, f.title, f.poster_url, f.status, f.created_at,
            (SELECT COUNT(*) FROM episodes e WHERE e.film_id = f.id) AS episode_count,
            (SELECT COUNT(*) FROM likes l WHERE l.film_id = f.id) AS like_count,
            (SELECT COUNT(*) FROM comments c WHERE c.film_id = f.id) AS comment_count,
            (SELECT COALESCE(SUM(ue.coins_spent), 0) FROM unlocked_episodes ue
               JOIN episodes e ON e.id = ue.episode_id WHERE e.film_id = f.id) AS coins_spent
       FROM films f
      WHERE f.catalog_drama_id IS NULL
      ORDER BY f.id`,
  );
  return rows.map((r) => ({
    ...r,
    episode_count: Number(r.episode_count),
    like_count: Number(r.like_count),
    comment_count: Number(r.comment_count),
    coins_spent: Number(r.coins_spent),
  }));
};

async function ownFilm(db, filmId) {
  const [rows] = await db.query(
    'SELECT id FROM films WHERE id = ? AND catalog_drama_id IS NULL',
    [filmId],
  );
  if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
}

exports.setFilmStatus = async (pool, filmId, status) => {
  await ownFilm(pool, filmId);
  await pool.query('UPDATE films SET status = ? WHERE id = ?', [status, filmId]);
};

exports.listEpisodes = async (pool, filmId) => {
  await ownFilm(pool, filmId);
  const [rows] = await pool.query(
    `SELECT e.id, e.episode_no, e.title, e.duration_sec, e.is_free, e.price_coins,
            (SELECT COUNT(*) FROM unlocked_episodes ue WHERE ue.episode_id = e.id) AS unlock_count
       FROM episodes e WHERE e.film_id = ? ORDER BY e.episode_no`,
    [filmId],
  );
  return rows.map((r) => ({ ...r, is_free: Boolean(r.is_free), unlock_count: Number(r.unlock_count) }));
};

// A free episode costs 0; a paid one needs a price above 0.
exports.updateEpisode = async (pool, episodeId, { isFree, priceCoins }) => {
  const [rows] = await pool.query(
    `SELECT e.id, e.is_free, e.price_coins FROM episodes e
       JOIN films f ON f.id = e.film_id
      WHERE e.id = ? AND f.catalog_drama_id IS NULL`,
    [episodeId],
  );
  if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  const free = isFree ?? Boolean(rows[0].is_free);
  const price = free ? 0 : (priceCoins ?? rows[0].price_coins);
  if (!free && price < 1) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'A paid episode needs a price of at least 1 coin');
  }
  await pool.query('UPDATE episodes SET is_free = ?, price_coins = ? WHERE id = ?', [
    free ? 1 : 0,
    price,
    episodeId,
  ]);
  return { id: episodeId, is_free: free, price_coins: price };
};

// ---- comments -------------------------------------------------------------

exports.listComments = async (pool, { filmId, limit, offset }) => {
  const [rows] = await pool.query(
    `SELECT c.id, c.body, c.created_at, c.user_id, u.username,
            c.film_id, f.title AS film_title
       FROM comments c
       JOIN users u ON u.id = c.user_id
       JOIN films f ON f.id = c.film_id
      ${filmId ? 'WHERE c.film_id = ?' : ''}
      ORDER BY c.id DESC LIMIT ? OFFSET ?`,
    filmId ? [filmId, limit, offset] : [limit, offset],
  );
  return rows;
};

// ---- settings -------------------------------------------------------------

// The settings the admin may change, with their allowed range.
exports.SETTINGS = {
  demo_topup_coins: { min: 1, max: 10000 },
  catalog_free_episodes: { min: 0, max: 1000 },
  catalog_price_coins: { min: 1, max: 10000 },
};

exports.getSettings = async (pool) => {
  const [rows] = await pool.query('SELECT name, value FROM settings');
  const out = {};
  for (const r of rows) if (r.name in exports.SETTINGS) out[r.name] = Number(r.value);
  return out;
};

exports.saveSettings = async (pool, values) => {
  for (const [name, value] of Object.entries(values)) {
    await pool.query(
      'INSERT INTO settings (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
      [name, String(value)],
    );
  }
  return exports.getSettings(pool);
};

// ---- coin packs -----------------------------------------------------------

exports.listCoinPacks = async (pool) => {
  const [rows] = await pool.query(
    `SELECT p.id, p.name, p.coins, p.price_usd,
            (SELECT COUNT(*) FROM coin_transactions t WHERE t.coin_pack_id = p.id) AS sold_count
       FROM coin_packs p ORDER BY p.coins`,
  );
  return rows.map((r) => ({ ...r, price_usd: Number(r.price_usd), sold_count: Number(r.sold_count) }));
};

exports.createCoinPack = async (pool, { name, coins, priceUsd }) => {
  const [result] = await pool.query(
    'INSERT INTO coin_packs (name, coins, price_usd) VALUES (?, ?, ?)',
    [name, coins, priceUsd],
  );
  return result.insertId;
};

exports.updateCoinPack = async (pool, id, { name, coins, priceUsd }) => {
  const [result] = await pool.query(
    'UPDATE coin_packs SET name = ?, coins = ?, price_usd = ? WHERE id = ?',
    [name, coins, priceUsd, id],
  );
  if (result.affectedRows === 0) throw new ApiError(404, 'NOT_FOUND', 'Coin pack not found');
};

// A pack that was already bought stays, so the wallet history keeps its name.
exports.deleteCoinPack = async (pool, id) => {
  const [[used]] = await pool.query(
    'SELECT COUNT(*) AS n FROM coin_transactions WHERE coin_pack_id = ?',
    [id],
  );
  if (Number(used.n) > 0) {
    throw new ApiError(409, 'IN_USE', 'This pack was already bought and cannot be deleted');
  }
  const [result] = await pool.query('DELETE FROM coin_packs WHERE id = ?', [id]);
  if (result.affectedRows === 0) throw new ApiError(404, 'NOT_FOUND', 'Coin pack not found');
};
