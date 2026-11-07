const admin = require('../models/admin');
const social = require('../models/social');
const { pathId, text, int, bool, bad } = require('../utils/validate');

const pool = (req) => req.app.locals.pool;

exports.sales = async (req, res) => {
  res.json(await admin.sales(pool(req)));
};

// ---- content ----

exports.listFilms = async (req, res) => {
  res.json({ films: await admin.listFilms(pool(req)) });
};

exports.setFilmStatus = async (req, res) => {
  const status = req.body?.status;
  if (status !== 'approved' && status !== 'taken_down') {
    throw bad('status must be approved or taken_down');
  }
  const id = pathId(req.params.id);
  await admin.setFilmStatus(pool(req), id, status);
  res.json({ id, status });
};

exports.listEpisodes = async (req, res) => {
  res.json({ episodes: await admin.listEpisodes(pool(req), pathId(req.params.id)) });
};

exports.updateEpisode = async (req, res) => {
  const isFree = bool(req.body, 'is_free', { optional: true });
  const priceCoins = int(req.body, 'price_coins', { min: 0, max: 10000, optional: true });
  if (isFree === undefined && priceCoins === undefined) throw bad('Nothing to change');
  res.json(await admin.updateEpisode(pool(req), pathId(req.params.id), { isFree, priceCoins }));
};

// ---- comments ----

exports.listComments = async (req, res) => {
  const limit = req.query.limit === undefined ? 50 : pathId(req.query.limit, 'limit');
  const offset = req.query.offset === undefined ? 0 : pathId(req.query.offset, 'offset');
  if (limit < 1 || limit > 200) throw bad('limit is not valid');
  const filmId = req.query.film_id === undefined ? undefined : pathId(req.query.film_id, 'film_id');
  const rows = await admin.listComments(pool(req), { filmId, limit: limit + 1, offset });
  res.json({ comments: rows.slice(0, limit), has_more: rows.length > limit });
};

exports.removeComment = async (req, res) => {
  await social.removeComment(pool(req), req.user, pathId(req.params.id));
  res.status(204).end();
};

// ---- settings ----

exports.getSettings = async (req, res) => {
  res.json({ settings: await admin.getSettings(pool(req)) });
};

exports.saveSettings = async (req, res) => {
  const body = req.body ?? {};
  const values = {};
  for (const name of Object.keys(body)) {
    const range = admin.SETTINGS[name];
    if (!range) throw bad(`${name} is not a setting`);
    values[name] = int(body, name, range);
  }
  if (Object.keys(values).length === 0) throw bad('Nothing to change');
  res.json({ settings: await admin.saveSettings(pool(req), values) });
};

// ---- coin packs ----

function packBody(body) {
  const name = text(body, 'name', { max: 30 });
  const coins = int(body, 'coins', { min: 1, max: 65535 });
  const price = Number(body?.price_usd);
  if (!Number.isFinite(price) || price <= 0 || price > 9999.99) throw bad('price_usd is not valid');
  return { name, coins, priceUsd: Math.round(price * 100) / 100 };
}

exports.listCoinPacks = async (req, res) => {
  res.json({ coin_packs: await admin.listCoinPacks(pool(req)) });
};

exports.createCoinPack = async (req, res) => {
  const id = await admin.createCoinPack(pool(req), packBody(req.body));
  res.status(201).json({ id });
};

exports.updateCoinPack = async (req, res) => {
  const id = pathId(req.params.id);
  await admin.updateCoinPack(pool(req), id, packBody(req.body));
  res.json({ id });
};

exports.deleteCoinPack = async (req, res) => {
  await admin.deleteCoinPack(pool(req), pathId(req.params.id));
  res.status(204).end();
};

