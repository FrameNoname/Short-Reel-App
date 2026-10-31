const PLACEHOLDER_SECRET = 'change-me';

function loadEnv(source = process.env) {
  if (!source.JWT_SECRET || source.JWT_SECRET === PLACEHOLDER_SECRET) {
    throw new Error('JWT_SECRET is required. Copy .env.example to .env and set a random value.');
  }
  return {
    port: Number(source.PORT ?? 3000),
    db: {
      host: source.DB_HOST ?? '127.0.0.1',
      port: Number(source.DB_PORT ?? 3306),
      user: source.DB_USER ?? 'root',
      password: source.DB_PASSWORD ?? '',
      database: source.DB_NAME ?? 'shortreel',
    },
    jwtSecret: source.JWT_SECRET,
    jwtExpiresIn: source.JWT_EXPIRES_IN ?? '7d',
    // Optional: without a key the /api/catalog routes answer 503.
    catalog: {
      apiKey: source.SERIESJEEN_API_KEY || undefined,
      baseUrl: source.SERIESJEEN_BASE_URL || undefined,
      allowGuest: source.CATALOG_ALLOW_GUEST === 'true',
    },
  };
}

module.exports = { loadEnv };
