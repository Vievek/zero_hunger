const app = require("../server");

// This is your Vercel serverless function handler
module.exports = async (req, res) => {
  // Add CORS headers for Vercel
  res.setHeader("Access-Control-Allow-Credentials", true);
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader(
    "Access-Control-Allow-Methods",
    "GET,OPTIONS,PATCH,DELETE,POST,PUT"
  );
  res.setHeader(
    "Access-Control-Allow-Headers",
    "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version"
  );

  // Handle OPTIONS for CORS preflight
  if (req.method === "OPTIONS") {
    res.status(200).end();
    return;
  }

  return app(req, res);
};
