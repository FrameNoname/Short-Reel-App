const multer = require('multer');
const ApiError = require('../utils/ApiError');

function toApiError(err) {
  if (err instanceof ApiError) return err;
  if (err.type === 'entity.parse.failed') {
    return new ApiError(400, 'VALIDATION_ERROR', 'Request body is not valid JSON');
  }
  if (err instanceof multer.MulterError) {
    return err.code === 'LIMIT_FILE_SIZE'
      ? new ApiError(413, 'FILE_TOO_LARGE', 'File is too large')
      : new ApiError(400, 'VALIDATION_ERROR', err.message);
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
