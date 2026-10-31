const films = require('../models/films');
const creator = require('../models/creator');
const wallet = require('../models/wallet');

// The creator's own films in every review status, so they can follow a review.
exports.listFilms = async (req, res) => {
  const rows = await films.search(req.app.locals.pool, {
    creatorId: req.user.id,
    sort: 'latest',
    limit: 100,
    offset: 0,
  });
  res.json({ films: rows.map((row) => films.serialize(row, { includePrivate: true })) });
};

exports.earnings = async (req, res) => {
  const pool = req.app.locals.pool;
  res.json({
    ...(await creator.earnings(pool, req.user.id)),
    // Shown so a creator can see how each unlock is split.
    admin_share_percent: await wallet.adminSharePercent(pool),
  });
};
