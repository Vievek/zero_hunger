const NodeCache = require("node-cache");

class CacheManager {
  constructor() {
    this.cache = new NodeCache({
      stdTTL: 3600, // Default TTL: 1 hour
      checkperiod: 600, // Check for expired keys every 10 minutes
      useClones: false, // Better performance for objects
    });

    console.log("Cache manager initialized");
  }

  // Set a value in cache
  async set(key, value, ttl = null) {
    try {
      const success = ttl
        ? this.cache.set(key, value, ttl)
        : this.cache.set(key, value);

      if (success) {
        console.log(`Cache SET: ${key} (TTL: ${ttl || "default"}s)`);
      } else {
        console.error(`Cache SET failed: ${key}`);
      }

      return success;
    } catch (error) {
      console.error(`Cache SET error for key ${key}:`, error);
      return false;
    }
  }

  // Get a value from cache
  async get(key) {
    try {
      const value = this.cache.get(key);
      if (value !== undefined) {
        console.log(`Cache HIT: ${key}`);
        return value;
      } else {
        console.log(`Cache MISS: ${key}`);
        return null;
      }
    } catch (error) {
      console.error(`Cache GET error for key ${key}:`, error);
      return null;
    }
  }

  // Delete a value from cache
  async del(key) {
    try {
      const deleted = this.cache.del(key);
      console.log(`Cache DEL: ${key} (${deleted} items deleted)`);
      return deleted;
    } catch (error) {
      console.error(`Cache DEL error for key ${key}:`, error);
      return 0;
    }
  }

  // Check if a key exists
  async has(key) {
    try {
      return this.cache.has(key);
    } catch (error) {
      console.error(`Cache HAS error for key ${key}:`, error);
      return false;
    }
  }

  // Get multiple values
  async mget(keys) {
    try {
      return this.cache.mget(keys);
    } catch (error) {
      console.error(`Cache MGET error for keys:`, keys, error);
      return {};
    }
  }

  // Set multiple values
  async mset(keyValuePairs, ttl = null) {
    try {
      if (ttl) {
        // NodeCache doesn't support TTL for mset, so we set individually
        const results = await Promise.all(
          Object.entries(keyValuePairs).map(([key, value]) =>
            this.set(key, value, ttl)
          )
        );
        return results.every((result) => result === true);
      } else {
        return this.cache.mset(keyValuePairs);
      }
    } catch (error) {
      console.error("Cache MSET error:", error);
      return false;
    }
  }

  // Get cache statistics
  async getStats() {
    try {
      const stats = this.cache.getStats();
      return {
        hits: stats.hits,
        misses: stats.misses,
        keys: stats.keys,
        ksize: stats.ksize,
        vsize: stats.vsize,
        hitRate: stats.hits / (stats.hits + stats.misses) || 0,
      };
    } catch (error) {
      console.error("Cache stats error:", error);
      return null;
    }
  }

  // Flush entire cache
  async flush() {
    try {
      this.cache.flushAll();
      console.log("Cache flushed");
      return true;
    } catch (error) {
      console.error("Cache flush error:", error);
      return false;
    }
  }

  // Get all keys (use with caution in production)
  async keys() {
    try {
      return this.cache.keys();
    } catch (error) {
      console.error("Cache keys error:", error);
      return [];
    }
  }

  // Cache with fallback function
  async cached(key, fallbackFunction, ttl = null) {
    try {
      // Try to get from cache first
      const cachedValue = await this.get(key);
      if (cachedValue !== null) {
        return cachedValue;
      }

      // If not in cache, execute fallback function
      console.log(`Cache MISS - executing fallback for: ${key}`);
      const freshValue = await fallbackFunction();

      // Store in cache for future requests
      if (freshValue !== null && freshValue !== undefined) {
        await this.set(key, freshValue, ttl);
      }

      return freshValue;
    } catch (error) {
      console.error(`Cached function error for key ${key}:`, error);
      // If cache fails, still try to execute fallback
      try {
        return await fallbackFunction();
      } catch (fallbackError) {
        console.error(
          `Fallback function also failed for key ${key}:`,
          fallbackError
        );
        throw fallbackError;
      }
    }
  }

  // Cache with conditional TTL
  async cachedConditional(
    key,
    fallbackFunction,
    conditionChecker = null,
    ttl = null
  ) {
    const value = await this.cached(key, fallbackFunction, ttl);

    if (conditionChecker && conditionChecker(value)) {
      // If condition is met, extend TTL or use different TTL
      await this.set(key, value, ttl * 2 || 7200); // Double TTL or 2 hours
    }

    return value;
  }

  // Cache with tags (simulated - NodeCache doesn't support tags natively)
  async setWithTags(key, value, tags = [], ttl = null) {
    const success = await this.set(key, value, ttl);

    if (success && tags.length > 0) {
      // Store tag relationships
      for (const tag of tags) {
        const tagKey = `tag:${tag}`;
        const taggedItems = (await this.get(tagKey)) || [];
        if (!taggedItems.includes(key)) {
          taggedItems.push(key);
          await this.set(tagKey, taggedItems, ttl);
        }
      }
    }

    return success;
  }

  // Get keys by tag
  async getByTag(tag) {
    const tagKey = `tag:${tag}`;
    const taggedItems = await this.get(tagKey);
    return taggedItems || [];
  }

  // Invalidate by tag
  async invalidateTag(tag) {
    const tagKey = `tag:${tag}`;
    const taggedItems = await this.get(tagKey);

    if (taggedItems && taggedItems.length > 0) {
      // Delete all items with this tag
      this.cache.del(taggedItems);
      // Delete the tag itself
      this.cache.del(tagKey);
      console.log(`Invalidated tag: ${tag} (${taggedItems.length} items)`);
    }

    return taggedItems ? taggedItems.length : 0;
  }

  // Cache with compression for large objects (simplified)
  async setCompressed(key, value, ttl = null) {
    try {
      // For large objects, you might want to compress them
      // This is a simplified version - in production, use proper compression
      const compressedValue = value; // Placeholder for compression logic
      return await this.set(key, compressedValue, ttl);
    } catch (error) {
      console.error(`Compressed cache SET error for key ${key}:`, error);
      return false;
    }
  }

  async getCompressed(key) {
    try {
      const compressedValue = await this.get(key);
      // Decompression logic would go here
      return compressedValue; // Placeholder for decompression
    } catch (error) {
      console.error(`Compressed cache GET error for key ${key}:`, error);
      return null;
    }
  }

  // Health check
  async healthCheck() {
    try {
      const testKey = "health-check";
      const testValue = { timestamp: Date.now(), status: "ok" };

      const setSuccess = await this.set(testKey, testValue, 10);
      const retrievedValue = await this.get(testKey);
      const delSuccess = await this.del(testKey);

      return {
        healthy: setSuccess && retrievedValue && delSuccess,
        set: setSuccess,
        get: !!retrievedValue,
        del: delSuccess,
        stats: await this.getStats(),
      };
    } catch (error) {
      console.error("Cache health check error:", error);
      return { healthy: false, error: error.message };
    }
  }
}

module.exports = new CacheManager();
