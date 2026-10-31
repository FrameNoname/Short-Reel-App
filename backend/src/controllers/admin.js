const ApiError = require('../utils/ApiError');
const { pathId, text, int, bad } = require('../utils/validate');
const admin = require('../models/admin');
const films = require('../models/films');
const wallet = require('../models/wallet');

const STATUSES = ['pending', 'approved', 'rejected', 'taken_down'];
const ROLES = ['viewer', 'creator', 'admin'];

async function filmsWithStatus(pool, status) {
  const rows = await films.search(pool, { status, sort: 'latest', limit: 100, offset: 0 });
  return rows.map((row) => films.serialize(row, { includePrivate: true }));
}

exports.listReviews = async (req, res) => {
  res.json({ films: await filmsWithStatus(req.app.locals.pool, 'pending') });
};

exports.listFilms = async (req, res) => {
  const status = req.query.status ?? 'approved';
  if (!STATUSES.includes(status)) throw bad('status is not valid');
  res.json({ films: await filmsWithStatus(req.app.locals.pool, status) });
};

exports.reviewFilm = async (req, res) => {
  const pool = req.app.locals.pool;
  const status = req.body?.status;
  if (!admin.REVIEW_STATUSES.includes(status)) throw bad('status must be approved, rejected or taken_down');
  const note = text(req.body, 'note', { max: 255, optional: true });
  await admin.review(pool, pathId(req.params.id), { status, note, adminId: req.user.id });
  const film = await films.findById(pool, pathId(req.params.id));
  res.json({ film: films.serialize(film, { includePrivate: true }) });
};

exports.sales = async (req, res) => {
  const pool = req.app.locals.pool;
  res.json({
    admin_share_percent: await wallet.adminSharePercent(pool),
    ...(await admin.sales(pool)),
  });
};

exports.getRevenueShare = async (req, res) => {
  res.json({ admin_share_percent: await wallet.adminSharePercent(req.app.locals.pool) });
};

exports.setRevenueShare = async (req, res) => {
  const percent = int(req.body, 'admin_share_percent', { min: 0, max: 100 });
  await admin.setSharePercent(req.app.locals.pool, percent);
  res.json({ admin_share_percent: percent, applies_to: 'unlocks made from now on' });
};

exports.listUsers = async (req, res) => {
  res.json({ users: await admin.listUsers(req.app.locals.pool) });
};

exports.setUserRole = async (req, res) => {
  const pool = req.app.locals.pool;
  const id = pathId(req.params.id);
  const role = req.body?.role;
  if (!ROLES.includes(role)) throw bad('role is not valid');
  if (id === req.user.id) throw new ApiError(409, 'CONFLICT', 'You cannot change your own role');
  const [rows] = await pool.query('SELECT id FROM users WHERE id = ?', [id]);
  if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'User not found');
  await admin.setRole(pool, id, role);
  res.json({ id, role });
};

exports.listReports = async (req, res) => {
  res.json({ reports: await admin.listReports(req.app.locals.pool) });
};

exports.resolveReport = async (req, res) => {
  if ((await admin.resolveReport(req.app.locals.pool, pathId(req.params.id))) === 0) {
    throw new ApiError(404, 'NOT_FOUND', 'Report not found');
  }
  res.json({ status: 'resolved' });
};
