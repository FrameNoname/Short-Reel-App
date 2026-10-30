function loadEnv(source = process.env) {
  if (!source.JWT_SECRET) {
    throw new Error('JWT_SECRET is required. Copy .env.example to .env and set it.');
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
  };
}

module.exports = { loadEnv };
