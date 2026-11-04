const ApiError = require('../utils/ApiError');
const { pathId, bad } = require('../utils/validate');
const admin = require('../models/admin');
const films = require('../models/films');

// A film is either live in the catalogue or taken down by the admin.
const STATUSES = ['approved', 'taken_down'];

exports.listFilms = async (req, res) => {
  const status = req.query.status ?? 'approved';
  if (!STATUSES.includes(status)) throw bad('status is not valid');
  const rows = await films.search(req.app.locals.pool, { status, sort: 'latest', limit: 100, offset: 0 });
  res.json({ films: rows.map((row) => films.serialize(row)) });
};

// Takes a film down, or puts a taken-down film back in the catalogue.
exports.setFilmStatus = async (req, res) => {
  const pool = req.app.locals.pool;
  const id = pathId(req.params.id);
  const status = req.body?.status;
  if (!STATUSES.includes(status)) throw bad('status must be approved or taken_down');
  const [result] = await films.setStatus(pool, id, status);
  if (result.affectedRows === 0) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
  res.json({ film: films.serialize(await films.findById(pool, id)) });
};

exports.sales = async (req, res) => {
  res.json(await admin.sales(req.app.locals.pool));
};
