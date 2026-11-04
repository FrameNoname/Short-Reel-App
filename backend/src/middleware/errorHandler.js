const ApiError = require('../utils/ApiError');

function toApiError(err) {
  if (err instanceof ApiError) return err;
  if (err.type === 'entity.parse.failed') {
    return new ApiError(400, 'VALIDATION_ERROR', 'Request body is not valid JSON');
  }
  if (err.type === 'entity.too.large') {
    return new ApiError(413, 'FILE_TOO_LARGE', 'Request body is too large');
  }
  if (err.status >= 400 && err.status < 500) {
    return new ApiError(400, 'VALIDATION_ERROR', 'Request is not valid');
  }
  return new ApiError(500, 'INTERNAL_ERROR', 'Something went wrong');
}

// Express identifies error middleware by its four parameters.
function errorHandler(err, req, res, next) {
  const apiError = toApiError(err);
  if (apiError.status >= 500 && apiError.code === 'INTERNAL_ERROR') console.error(err);
  res.status(apiError.status).json({
    error: { code: apiError.code, message: apiError.message },
  });
}

module.exports = errorHandler;
