const admin = require('../models/admin');

exports.sales = async (req, res) => {
  res.json(await admin.sales(req.app.locals.pool));
};
