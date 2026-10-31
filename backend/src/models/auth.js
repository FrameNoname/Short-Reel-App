const USER_COLUMNS = 'id, username, display_name, avatar_url, bio, role, coin_balance, created_at';

exports.findByUsername = async (pool, username) => {
  const [rows] = await pool.query(`SELECT ${USER_COLUMNS}, password FROM users WHERE username = ?`, [
    username,
  ]);
  return rows[0];
};

exports.findById = async (pool, id) => {
  const [rows] = await pool.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = ?`, [id]);
  return rows[0];
};

exports.create = async (pool, { username, passwordHash, displayName, role }) => {
  const [result] = await pool.query(
    'INSERT INTO users (username, password, display_name, role) VALUES (?, ?, ?, ?)',
    [username, passwordHash, displayName, role],
  );
  return result.insertId;
};

exports.updateProfile = (pool, id, { displayName, bio }) =>
  pool.query('UPDATE users SET display_name = ?, bio = ? WHERE id = ?', [displayName, bio, id]);
