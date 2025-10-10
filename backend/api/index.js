const app = require("../server");
const connectDB = require("../config/database");

// Global variable to track connection state
let isConnecting = false;

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader("Access-Control-Allow-Credentials", true);
  res.setHeader("Access-Control-Allow-Origin", process.env.FRONTEND_URL || "*");
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

  try {
    // Lazy database connection for each request in serverless
    const mongoose = require("mongoose");
    if (mongoose.connection.readyState !== 1 && !isConnecting) {
      isConnecting = true;
      console.log("Attempting database connection for request...");
      try {
        await connectDB();
        console.log("Database connected for request");
      } catch (error) {
        console.error("Database connection failed for request:", error.message);
        // Continue without database for read-only operations
      } finally {
        isConnecting = false;
      }
    }

    return app(req, res);
  } catch (error) {
    console.error("API handler error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};
