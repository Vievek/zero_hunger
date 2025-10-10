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

// Database connection
console.log("🗄️  Connecting to database...");
connectDB()
  .then(() => {
    console.log("✅ Database connection established");
  })
  .catch((error) => {
    console.error("❌ Database connection failed:", error);
  });

// Import and mount routes with detailed error handling
console.log("🛣️  Setting up routes...");

const loadAndMountRoute = (routePath, mountPath, routeName) => {
  try {
    console.log(`   🔍 Loading ${routeName} from ${routePath}...`);

    // Clear the require cache to ensure fresh import
    delete require.cache[require.resolve(routePath)];

    const routeModule = require(routePath);

    // Check if it's a valid router
    if (typeof routeModule !== "function") {
      throw new Error(`Expected function but got ${typeof routeModule}`);
    }

    if (!routeModule.stack) {
      throw new Error(`Not a valid Express router - missing stack property`);
    }

    app.use(mountPath, routeModule);
    console.log(
      `   ✅ ${routeName} mounted at ${mountPath} (${routeModule.stack.length} routes)`
    );
    return true;
  } catch (error) {
    console.error(`   ❌ Failed to mount ${routeName}:`, error.message);

    // More detailed error information
    if (error.message.includes("middleware function")) {
      console.error(
        `      💡 Issue: Router.use() requires a middleware function`
      );
      console.error(
        `      🔧 Check: Ensure ${routeName} exports a valid Express router`
      );
      console.error(`      📁 File: ${routePath}`);
    } else if (error.message.includes("callback function")) {
      console.error(
        `      💡 Issue: Route method requires a callback function`
      );
      console.error(
        `      🔧 Check: Verify all route definitions in ${routeName}`
      );
      console.error(`      📁 File: ${routePath}`);
    } else if (error.message.includes("Cannot find module")) {
      console.error(`      💡 Issue: Module not found`);
      console.error(`      🔧 Check: Verify file exists at ${routePath}`);
    } else if (error.message.includes("stack property")) {
      console.error(`      💡 Issue: Not a valid Express router`);
      console.error(
        `      🔧 Check: Ensure ${routeName} exports router, not controller`
      );
    }

    return false;
  }
};

// Mount routes with error handling
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

// Health check endpoint
app.get("/api/health", async (req, res) => {
  try {
    const connectionState = mongoose.connection.readyState;
    const dbStatus = connectionState === 1 ? "connected" : "disconnected";

    res.json({
      success: true,
      status: dbStatus === "connected" ? "healthy" : "degraded",
      message: `Server is running, database is ${dbStatus}`,
      timestamp: new Date().toISOString(),
      routes: {
        total: routes.length,
        loaded: successfulMounts,
        failed: routes.length - successfulMounts,
      },
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

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log("=".repeat(50));
  console.log(`🎉 Zero Hunger Backend Server Started!`);
  console.log(`📍 Port: ${PORT}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`📊 Routes: ${successfulMounts}/${routes.length} loaded`);
  console.log("=".repeat(50));
  console.log("📋 Available Endpoints:");
  console.log("   🔐 Auth: /api/auth");
  console.log("   🎁 Donations: /api/donations");
  console.log("   🍽️  FoodSafe: /api/foodsafe");
  console.log("   🚚 Logistics: /api/logistics");
  console.log("   👨‍💼 Admin: /api/admin");
  console.log("   🏥 Health: /api/health");
  console.log("=".repeat(50));
});

module.exports = app;
