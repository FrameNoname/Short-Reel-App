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
