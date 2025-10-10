const rateLimit = require("express-rate-limit");

// Different rate limit configurations for different types of endpoints
const createRateLimiter = (options = {}) => {
  const {
    windowMs = 15 * 60 * 1000, // 15 minutes
    max = 100, // limit each IP to 100 requests per windowMs
    message = "Too many requests from this IP, please try again later.",
    skipSuccessfulRequests = false,
    skipFailedRequests = false,
    keyGenerator = (req) => req.ip,
    skip = () => false,
    standardHeaders = true,
    legacyHeaders = false,
  } = options;

  return rateLimit({
    windowMs,
    max,
    message: {
      success: false,
      message,
      retryAfter: Math.ceil(windowMs / 1000),
    },
    skipSuccessfulRequests,
    skipFailedRequests,
    keyGenerator,
    skip,
    standardHeaders,
    legacyHeaders,
    handler: (req, res) => {
      res.status(429).json({
        success: false,
        message,
        retryAfter: Math.ceil(windowMs / 1000),
      });
    },
  });
};

// Strict limiter for authentication endpoints
const authLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per 15 minutes
  message: "Too many authentication attempts, please try again later.",
  skipSuccessfulRequests: true, // Only count failed attempts
});

// Standard API limiter for most endpoints
const apiLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per 15 minutes
  message: "Too many API requests, please try again later.",
});

// More permissive limiter for donation creation
const donationLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // 10 donations per hour
  message: "Too many donation creations, please try again later.",
});

// Strict limiter for image uploads
const uploadLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20, // 20 uploads per hour
  message: "Too many image uploads, please try again later.",
});

// Permissive limiter for public endpoints
const publicLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200, // 200 requests per 15 minutes
  message: "Too many requests, please try again later.",
});

// Very strict limiter for sensitive operations
const sensitiveLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 sensitive operations per hour
  message: "Too many sensitive operations, please try again later.",
});

// Custom key generator that includes user ID for authenticated requests
const userAwareKeyGenerator = (req) => {
  if (req.user && req.user.id) {
    return `${req.ip}-${req.user.id}`;
  }
  return req.ip;
};

// User-aware rate limiter
const userAwareLimiter = createRateLimiter({
  keyGenerator: userAwareKeyGenerator,
  windowMs: 15 * 60 * 1000,
  max: 150, // Higher limit for authenticated users
});

// Skip function for health checks and important endpoints
const skipImportantRequests = (req) => {
  // Skip rate limiting for health checks
  if (req.path === "/health") return true;

  // Skip rate limiting for certain user roles
  if (req.user && req.user.role === "admin") return true;

  return false;
};

// Admin-friendly limiter
const adminFriendlyLimiter = createRateLimiter({
  skip: skipImportantRequests,
  windowMs: 15 * 60 * 1000,
  max: 1000, // Very high limit with skip for admins
});

// Rate limit store (in production, use Redis or other distributed store)
const createMemoryStore = () => {
  const store = new Map();

  return {
    increment: (key, windowMs, cb) => {
      const now = Date.now();
      const windowStart = Math.floor(now / windowMs) * windowMs;
      const recordKey = `${key}-${windowStart}`;

      const current = store.get(recordKey) || {
        count: 0,
        resetTime: windowStart + windowMs,
      };
      current.count++;
      store.set(recordKey, current);

      // Clean up old records (basic garbage collection)
      const cleanupTime = now - 2 * windowMs;
      for (const [key, value] of store.entries()) {
        if (value.resetTime < cleanupTime) {
          store.delete(key);
        }
      }

      cb(null, current.count, current.resetTime);
    },

    // For testing and debugging
    _getStore: () => store,
    _clear: () => store.clear(),
  };
};

// Dynamic rate limiting based on request characteristics
const dynamicRateLimiter = (req, res, next) => {
  let windowMs = 15 * 60 * 1000; // 15 minutes default
  let max = 100; // 100 requests default

  // Adjust limits based on request type
  if (req.path.startsWith("/auth/")) {
    windowMs = 15 * 60 * 1000;
    max = 5;
  } else if (req.path.startsWith("/donations") && req.method === "POST") {
    windowMs = 60 * 60 * 1000;
    max = 10;
  } else if (req.path.startsWith("/upload")) {
    windowMs = 60 * 60 * 1000;
    max = 20;
  } else if (req.user && req.user.role === "volunteer") {
    // Higher limits for volunteers
    max = 200;
  } else if (req.user && req.user.role === "admin") {
    // Very high limits for admins
    max = 1000;
  }

  const limiter = createRateLimiter({
    windowMs,
    max,
    keyGenerator: userAwareKeyGenerator,
    skip: skipImportantRequests,
  });

  limiter(req, res, next);
};

// Rate limit analytics and monitoring
const rateLimitAnalytics = (req, res, next) => {
  const startTime = Date.now();

  // Store original send function
  const originalSend = res.send;

  res.send = function (data) {
    const duration = Date.now() - startTime;

    // Log rate limit hits
    if (res.statusCode === 429) {
      console.warn(`Rate limit exceeded:`, {
        ip: req.ip,
        user: req.user?.id || "anonymous",
        path: req.path,
        method: req.method,
        userAgent: req.get("User-Agent"),
        timestamp: new Date().toISOString(),
      });
    }

    // Log slow requests that might indicate abuse
    if (duration > 5000) {
      // 5 seconds
      console.warn(`Slow request detected:`, {
        ip: req.ip,
        path: req.path,
        method: req.method,
        duration: `${duration}ms`,
        user: req.user?.id || "anonymous",
      });
    }

    // Call original send
    originalSend.call(this, data);
  };

  next();
};

// Export all rate limiters
module.exports = {
  // Basic limiters
  authLimiter,
  apiLimiter,
  donationLimiter,
  uploadLimiter,
  publicLimiter,
  sensitiveLimiter,

  // Advanced limiters
  userAwareLimiter,
  adminFriendlyLimiter,
  dynamicRateLimiter,

  // Utilities
  createRateLimiter,
  createMemoryStore,
  rateLimitAnalytics,

  // Configuration
  config: {
    // Default settings that can be overridden
    defaultWindowMs: 15 * 60 * 1000,
    defaultMax: 100,

    // Environment-based settings
    isProduction: process.env.NODE_ENV === "production",

    // Whitelist certain IPs or ranges
    whitelist: process.env.RATE_LIMIT_WHITELIST
      ? process.env.RATE_LIMIT_WHITELIST.split(",")
      : [],

    // Blacklist certain IPs or ranges
    blacklist: process.env.RATE_LIMIT_BLACKLIST
      ? process.env.RATE_LIMIT_BLACKLIST.split(",")
      : [],
  },

  // Helper function to check if an IP is whitelisted
  isWhitelisted: (ip) => {
    const whitelist = process.env.RATE_LIMIT_WHITELIST
      ? process.env.RATE_LIMIT_WHITELIST.split(",")
      : [];
    return whitelist.includes(ip);
  },

  // Helper function to check if an IP is blacklisted
  isBlacklisted: (ip) => {
    const blacklist = process.env.RATE_LIMIT_BLACKLIST
      ? process.env.RATE_LIMIT_BLACKLIST.split(",")
      : [];
    return blacklist.includes(ip);
  },
};
