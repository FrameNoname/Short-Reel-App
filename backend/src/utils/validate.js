const ApiError = require('./ApiError');

const bad = (message) => new ApiError(400, 'VALIDATION_ERROR', message);

function pathId(value, name = 'id') {
  if (!/^\d{1,9}$/.test(String(value))) throw bad(`${name} is not valid`);
  return Number(value);
}

function text(body, key, { min = 1, max, optional = false } = {}) {
  const raw = body?.[key];
  if (raw === undefined || raw === null || raw === '') {
    if (optional) return undefined;
    throw bad(`${key} is required`);
  }
  if (typeof raw !== 'string') throw bad(`${key} must be text`);
  const value = raw.trim();
  if (value.length < min || (max && value.length > max)) {
    throw bad(`${key} must be ${min}-${max} characters`);
  }
  return value;
}

// Accepts numbers and numeric strings, because multipart fields are text.
function int(body, key, { min, max, optional = false } = {}) {
  const raw = body?.[key];
  if (raw === undefined || raw === null || raw === '') {
    if (optional) return undefined;
    throw bad(`${key} is required`);
  }
  const n = typeof raw === 'string' && /^-?\d+$/.test(raw.trim()) ? Number(raw) : raw;
  if (!Number.isInteger(n) || n < min || n > max) throw bad(`${key} is not valid`);
  return n;
}

function bool(body, key, { optional = false } = {}) {
  const raw = body?.[key];
  if (raw === undefined || raw === null || raw === '') {
    if (optional) return undefined;
    throw bad(`${key} is required`);
  }
  if (raw === true || raw === 'true' || raw === '1' || raw === 1) return true;
  if (raw === false || raw === 'false' || raw === '0' || raw === 0) return false;
  throw bad(`${key} must be true or false`);
}

module.exports = { pathId, text, int, bool, bad };
