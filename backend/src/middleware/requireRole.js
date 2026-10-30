const ApiError = require('../utils/ApiError');

// Must run after requireAuth, which sets req.user.
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      throw new ApiError(403, 'FORBIDDEN', 'You do not have access to this resource');
    }
    next();
  };
}

module.exports = requireRole;
