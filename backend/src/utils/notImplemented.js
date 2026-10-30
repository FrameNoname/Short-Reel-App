const ApiError = require('./ApiError');

function notImplemented(req, res, next) {
  next(new ApiError(501, 'NOT_IMPLEMENTED', 'This endpoint is not implemented yet'));
}

module.exports = notImplemented;
