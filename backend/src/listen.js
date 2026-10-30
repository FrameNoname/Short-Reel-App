// Express 5 passes listen errors to the callback instead of throwing them.
function listen(app, port, host) {
  return new Promise((resolve, reject) => {
    const server = app.listen(port, host, (err) => {
      if (err) reject(err);
      else resolve(server);
    });
  });
}

module.exports = { listen };
