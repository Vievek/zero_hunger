const app = require("../server");

module.exports = async (req, res) => {
  // Let the main server handle everything
  return app(req, res);
};
