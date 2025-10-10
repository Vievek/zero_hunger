const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");

const app = express();

// Middleware
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
  })
);

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Passport
require("./config/passport")(passport);
app.use(passport.initialize());

// Lazy database connection - don't connect on cold start
let dbConnected = false;

const connectDBLazily = async () => {
  if (!dbConnected) {
    try {
      const connectDB = require("./config/database");
      await connectDB();
      dbConnected = true;
    } catch (error) {
      console.error("Database connection failed:", error.message);
      dbConnected = false;
    }
  }
  return dbConnected;
};

// Routes with lazy database connection
const routes = [
  { path: "./routes/auth", mount: "/api/auth", name: "Auth Routes" },
  {
    path: "./routes/donations",
    mount: "/api/donations",
    name: "Donation Routes",
  },
  {
    path: "./routes/foodsafe",
    mount: "/api/foodsafe",
    name: "FoodSafe Routes",
  },
  {
    path: "./routes/logistics",
    mount: "/api/logistics",
    name: "Logistics Routes",
  },
  { path: "./routes/admin", mount: "/api/admin", name: "Admin Routes" },
];

// Mount routes
routes.forEach((route) => {
  try {
    const routeModule = require(route.path);
    app.use(route.mount, routeModule);
    console.log(`✅ ${route.name} mounted at ${route.mount}`);
  } catch (error) {
    console.error(`❌ Failed to mount ${route.name}:`, error.message);
    // Create placeholder route
    app.use(route.mount, (req, res) => {
      res.status(503).json({
        success: false,
        message: `${route.name} temporarily unavailable`,
      });
    });
  }
});

// Health check with database connection test
app.get("/api/health", async (req, res) => {
  const dbStatus =
    mongoose.connection.readyState === 1 ? "connected" : "disconnected";

  let dbHealthy = false;
  if (mongoose.connection.readyState === 1) {
    try {
      await mongoose.connection.db.admin().ping();
      dbHealthy = true;
    } catch (error) {
      dbHealthy = false;
    }
  }

  res.json({
    success: true,
    status: dbHealthy ? "healthy" : "degraded",
    message: `Server running, database ${
      dbHealthy ? "connected" : "disconnected"
    }`,
    timestamp: new Date().toISOString(),
    database: {
      state: mongoose.connection.readyState,
      status: dbStatus,
      healthy: dbHealthy,
    },
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    message: "Zero Hunger API is running",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
    path: req.originalUrl,
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error("Global error:", error);
  res.status(500).json({
    success: false,
    message: "Internal server error",
    error: process.env.NODE_ENV === "production" ? {} : error.message,
  });
});

// Only start server if not in Vercel
if (process.env.VERCEL !== "1") {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

module.exports = app;
