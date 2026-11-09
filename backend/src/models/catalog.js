// Series Jeen (FreeReels) series sold for coins. The early episodes are free; a later one
// is paid once and stays open. A series and its paid episodes become rows in
// films/episodes the first time someone unlocks one, so unlocking, the ledger
// and admin sales all run through the same tables as the app's own films.
const { setting } = require('./wallet');
const { isAdmin } = require('./access');

const TITLE_MAX = 100;
const POSTER_MAX = 255;

// A cover link too long for the column is left out rather than cut.
const posterOrNull = (url) => (url && String(url).length <= POSTER_MAX ? String(url) : null);

// The catalog names a series with a string id; the app, films and unlocks use
// a number. catalog_series gives each string id a number the first time it is
// seen, so the same series always gets the same number.
exports.idsFor = async (db, seriesIds) => {
  const unique = [...new Set(seriesIds.map(String))];
  if (unique.length === 0) return new Map();
  const lookup = async () => {
    const [rows] = await db.query('SELECT id, series_id FROM catalog_series WHERE series_id IN (?)', [unique]);
    return new Map(rows.map((r) => [r.series_id, r.id]));
  };
  const known = await lookup();
  const missing = unique.filter((s) => !known.has(s));
  if (missing.length === 0) return known;
  // Only new ids are inserted, so repeat lists do not burn auto-increment
  // numbers. IGNORE covers two requests adding the same id at once.
  await db.query(
    `INSERT IGNORE INTO catalog_series (series_id) VALUES ${missing.map(() => '(?)').join(', ')}`,
    missing,
  );
  return lookup();
};

// The catalog's string id for one of our numbers, or null if we never saw it.
exports.seriesIdOf = async (db, id) => {
  const [[row]] = await db.query('SELECT series_id FROM catalog_series WHERE id = ?', [id]);
  return row ? row.series_id : null;
};

// The drama numbers among `ids` the admin took down.
exports.takenDownIds = async (db, ids) => {
  if (ids.length === 0) return new Set();
  const [rows] = await db.query(
    "SELECT catalog_drama_id FROM films WHERE status = 'taken_down' AND catalog_drama_id IN (?)",
    [ids],
  );
  return new Set(rows.map((r) => r.catalog_drama_id));
};

exports.isTakenDown = async (db, dramaId) => (await exports.takenDownIds(db, [dramaId])).size > 0;

// Admin rows for these drama numbers, by drama number.
exports.filmsOf = async (db, ids) => {
  if (ids.length === 0) return new Map();
  const [rows] = await db.query(
    'SELECT id, catalog_drama_id, status FROM films WHERE catalog_drama_id IN (?)',
    [ids],
  );
  return new Map(rows.map((r) => [r.catalog_drama_id, r]));
};

// Takes a series down or brings it back. A series nobody bought yet has no
// films row, so one is made to hold the status.
exports.setStatus = async (db, { dramaId, title, poster, status }) => {
  await db.query(
    `INSERT INTO films (title, poster_url, is_ai_generated, catalog_drama_id, status) VALUES (?, ?, 0, ?, ?)
     ON DUPLICATE KEY UPDATE status = VALUES(status), title = VALUES(title),
       poster_url = COALESCE(VALUES(poster_url), poster_url)`,
    [String(title).slice(0, TITLE_MAX), posterOrNull(poster), dramaId, status],
  );
};

exports.pricing = async (db) => ({
  free_episodes: Number(await setting(db, 'catalog_free_episodes', 5)),
  price_coins: Number(await setting(db, 'catalog_price_coins', 10)),
});

// Episode numbers of one series that this user paid for.
async function unlockedNumbers(db, userId, dramaId) {
  const [rows] = await db.query(
    `SELECT e.episode_no FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      WHERE ue.user_id = ? AND f.catalog_drama_id = ?`,
    [userId, dramaId],
  );
  return new Set(rows.map((r) => r.episode_no));
}

// The episode numbers in [from, to] this caller may not play yet.
exports.lockedIn = async (db, user, dramaId, from, to) => {
  if (isAdmin(user)) return [];
  const { free_episodes: free } = await exports.pricing(db);
  const paid = [];
  for (let n = Math.max(from, free + 1); n <= to; n++) paid.push(n);
  if (paid.length === 0) return [];
  if (!user) return paid;
  const unlocked = await unlockedNumbers(db, user.id, dramaId);
  return paid.filter((n) => !unlocked.has(n));
};

// Every catalog episode this user paid for, as { drama_id, episode_no }.
exports.unlocksOf = async (db, userId) => {
  const [rows] = await db.query(
    `SELECT f.catalog_drama_id AS drama_id, e.episode_no
       FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      WHERE ue.user_id = ? AND f.catalog_drama_id IS NOT NULL
      ORDER BY f.catalog_drama_id, e.episode_no`,
    [userId],
  );
  return rows;
};

// The id of the episodes row for a paid catalog episode, creating the film and
// episode rows on first use. Both inserts are idempotent (unique keys), so two
// viewers unlocking the same new series at once end up with the same rows. The
// price follows the current setting, so a change applies to the next unlock.
exports.ensureEpisode = async (db, { dramaId, title, poster, episodeNo, priceCoins }) => {
  await db.query(
    `INSERT INTO films (title, poster_url, is_ai_generated, catalog_drama_id) VALUES (?, ?, 0, ?)
     ON DUPLICATE KEY UPDATE title = VALUES(title), poster_url = COALESCE(VALUES(poster_url), poster_url)`,
    [String(title).slice(0, TITLE_MAX), posterOrNull(poster), dramaId],
  );
  const [[film]] = await db.query('SELECT id FROM films WHERE catalog_drama_id = ?', [dramaId]);
  await db.query(
    `INSERT INTO episodes (film_id, episode_no, title, is_free, price_coins) VALUES (?, ?, ?, 0, ?)
     ON DUPLICATE KEY UPDATE price_coins = VALUES(price_coins)`,
    [film.id, episodeNo, `Episode ${episodeNo}`, priceCoins],
  );
  const [[episode]] = await db.query(
    'SELECT id FROM episodes WHERE film_id = ? AND episode_no = ?',
    [film.id, episodeNo],
  );
  return episode.id;
};
