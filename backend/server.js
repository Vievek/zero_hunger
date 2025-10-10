const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const passport = require("passport");
require("dotenv").config();

// Import database connection
const connectDB = require("./config/database");

const app = express();

console.log("🚀 Starting Zero Hunger Backend Server...");
console.log("📁 Environment:", process.env.NODE_ENV || "development");

// Enhanced CORS configuration
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
  })
);

console.log("🔧 CORS configured");

// Enhanced body parsing middleware
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

console.log("📦 Body parsing middleware configured");

// Passport config
console.log("🔐 Initializing Passport...");
require("./config/passport")(passport);
app.use(passport.initialize());
console.log("✅ Passport initialized");

// Database connection with retry logic for serverless
console.log("🗄️  Connecting to database...");

const initializeDatabase = async () => {
  try {
    await connectDB();
    console.log("✅ Database connection established");
    return true;
  } catch (error) {
    console.error("❌ Database connection failed:", error);
    return false;
  }
};

// Import and mount routes with detailed error handling
console.log("🛣️  Setting up routes...");

const loadAndMountRoute = (routePath, mountPath, routeName) => {
  try {
    console.log(`   🔍 Loading ${routeName} from ${routePath}...`);

    // For serverless, we need to handle dynamic imports differently
    const routeModule = require(routePath);

    // Check if it's a valid router
    if (typeof routeModule !== "function") {
      throw new Error(`Expected function but got ${typeof routeModule}`);
    }

    if (!routeModule.stack && !routeModule.handle) {
      throw new Error(`Not a valid Express router`);
    }

    app.use(mountPath, routeModule);
    console.log(`   ✅ ${routeName} mounted at ${mountPath}`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed to mount ${routeName}:`, error.message);

    // Create a placeholder route for health checks
    app.use(mountPath, (req, res) => {
      res.status(503).json({
        success: false,
        message: `${routeName} temporarily unavailable`,
        error: "Route loading failed",
      });
    });

    return false;
  }
};

// Mount routes - make sure these files exist in your deployment
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

let successfulMounts = 0;
routes.forEach((route) => {
  if (loadAndMountRoute(route.path, route.mount, route.name)) {
    successfulMounts++;
  }
});

console.log(
  `📊 Route Loading Summary: ${successfulMounts}/${routes.length} routes mounted successfully`
);

// Health check endpoint with database status
app.get("/api/health", async (req, res) => {
  try {
    const connectionState = mongoose.connection.readyState;
    const dbStatus = connectionState === 1 ? "connected" : "disconnected";

    // Test database connection if not connected
    let dbHealthy = false;
    if (connectionState === 1) {
      try {
        // Simple query to test connection
        await mongoose.connection.db.admin().ping();
        dbHealthy = true;
      } catch (pingError) {
        console.error("Database ping failed:", pingError);
        dbHealthy = false;
      }
    }

    res.json({
      success: true,
      status: dbHealthy ? "healthy" : "degraded",
      message: `Server is running, database is ${
        dbHealthy ? "connected" : "disconnected"
      }`,
      timestamp: new Date().toISOString(),
      database: {
        state: connectionState,
        status: dbStatus,
        healthy: dbHealthy,
      },
      routes: {
        total: routes.length,
        loaded: successfulMounts,
        failed: routes.length - successfulMounts,
      },
      environment: process.env.NODE_ENV || "development",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      status: "unhealthy",
      message: "Health check failed",
      error: process.env.NODE_ENV === "production" ? {} : error.message,
    });
  }
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    message: "Zero Hunger API is running",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development",
    endpoints: {
      auth: "/api/auth",
      donations: "/api/donations",
      foodsafe: "/api/foodsafe",
      logistics: "/api/logistics",
      admin: "/api/admin",
      health: "/api/health",
    },
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
  console.error("💥 Global error handler:", error);
  res.status(500).json({
    success: false,
    message: "Internal server error",
    error: process.env.NODE_ENV === "production" ? {} : error.message,
  });
});

// Initialize database on startup
initializeDatabase();

// Only start listening if not in serverless environment
if (process.env.NODE_ENV !== "production" || process.env.VERCEL !== "1") {
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => {
    console.log("=".repeat(50));
    console.log(`🎉 Zero Hunger Backend Server Started!`);
    console.log(`📍 Port: ${PORT}`);
    console.log(`🌐 Environment: ${process.env.NODE_ENV || "development"}`);
    console.log(`📊 Routes: ${successfulMounts}/${routes.length} loaded`);
    console.log("=".repeat(50));
  });
}

module.exports = app;
