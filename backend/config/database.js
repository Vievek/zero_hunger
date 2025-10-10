const mongoose = require("mongoose");

const options = {
  bufferCommands: false,
  bufferMaxEntries: 0,
  maxPoolSize: 5, // Increase pool size to allow concurrency
  minPoolSize: 1,
  serverSelectionTimeoutMS: 15000,
  socketTimeoutMS: 45000,
  connectTimeoutMS: 15000,
  retryWrites: true,
  retryReads: true,
  waitQueueTimeoutMS: 15000,
};

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function connectDB() {
  if (cached.conn && mongoose.connection.readyState === 1) {
    // Use cached connection if available and connected
    return cached.conn;
  }

  if (!cached.promise) {
    cached.promise = mongoose
      .connect(process.env.MONGODB_URI, options)
      .then((mongoose) => mongoose)
      .catch((err) => {
        cached.promise = null;
        throw err;
      });
  }

  cached.conn = await cached.promise;
  return cached.conn;
}

// Properly handle process termination in Vercel environment (optional)
process.on("SIGINT", async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.connection.close();
    console.log("MongoDB connection closed");
  }
  process.exit(0);
});

module.exports = connectDB;
