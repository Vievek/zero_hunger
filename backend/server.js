require("dotenv").config();

const express = require("express");
const connectDB = require("./config/database");
const cors = require("cors");

const app = express();

app.use(
  cors({
    origin: process.env.FRONTEND_URL || "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
      "Origin",
    ],
  })
);

app.use(express.json({ limit: "10mb" }));

// Connect to MongoDB before handling requests
app.use(async (req, res, next) => {
  try {
    await connectDB();
    next();
  } catch (error) {
    console.error("Database connection error:", error);
    res.status(503).json({ message: "Database connection error" });
  }
});

// Simple health check endpoint
app.get("/api/health", async (req, res) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      await connectDB();
    }
    await mongoose.connection.db.admin().ping();

    res.json({ status: "healthy", database: "connected" });
  } catch {
    res.status(503).json({ status: "unhealthy", database: "disconnected" });
  }
});

// Example route
app.get("/", (req, res) => {
  res.json({ message: "API is running" });
});

// Export app for Vercel serverless handler
module.exports = app;

// Only listen if NOT on Vercel (local dev)
if (!process.env.VERCEL) {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
}
