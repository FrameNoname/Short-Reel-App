const ApiError = require('../utils/ApiError');

const DEFAULT_BASE_URL = 'https://api-v2.seriesjeen.online';
const TIMEOUT_MS = 10000;

// The upstream key never leaves this process; the app only talks to our API.
function createCatalogClient({ apiKey, baseUrl = DEFAULT_BASE_URL, fetchImpl = fetch }) {
  async function get(path, query = {}) {
    const url = new URL(path, baseUrl);
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined) url.searchParams.set(key, String(value));
    }
    let res;
    try {
      res = await fetchImpl(url, {
        headers: { Authorization: `Bearer ${apiKey}` },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      throw new ApiError(502, 'CATALOG_UNREACHABLE', 'The catalog is not reachable');
    }
    if (res.ok) return res.json();
    throw toApiError(res);
  }

  return { get };
}

function toApiError(res) {
  switch (res.status) {
    case 403:
      return new ApiError(403, 'CATALOG_NO_ACCESS', 'No access to this platform');
    case 404:
      return new ApiError(404, 'NOT_FOUND', 'Not found in the catalog');
    case 429: {
      const err = new ApiError(429, 'CATALOG_RATE_LIMITED', 'The catalog is busy, try again soon');
      err.retryAfter = res.headers.get('retry-after');
      return err;
    }
    // A 401 means our own key is bad; the viewer can do nothing about it.
    default:
      return new ApiError(502, 'CATALOG_ERROR', 'The catalog could not answer');
  }
}

module.exports = { createCatalogClient };
