# Redis Cache Setup

## Overview

Redis is now deployed as a cache layer for your application.

## Connection Details

- **Service Name**: `redis-cache`
- **Port**: `6379`
- **Host**: `redis-cache` (within the same namespace)

## Using Redis in Your Application

### Install Redis Client

```bash
npm install redis
```

### Example Code (Node.js/Express)

```javascript
const redis = require("redis");

// Create Redis client
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || "redis-cache",
    port: process.env.REDIS_PORT || 6379,
  },
});

redisClient.on("error", (err) => console.error("Redis Client Error", err));
redisClient.connect();

// Cache middleware example
async function cacheMiddleware(req, res, next) {
  const key = `cache:${req.originalUrl}`;

  try {
    const cachedData = await redisClient.get(key);

    if (cachedData) {
      console.log("Cache hit:", key);
      return res.json(JSON.parse(cachedData));
    }

    console.log("Cache miss:", key);

    // Store the original res.json function
    const originalJson = res.json.bind(res);

    // Override res.json to cache the response
    res.json = (data) => {
      redisClient.setEx(key, 300, JSON.stringify(data)); // Cache for 5 minutes
      return originalJson(data);
    };

    next();
  } catch (err) {
    console.error("Cache error:", err);
    next();
  }
}

// Use in your routes
app.get("/api/users", cacheMiddleware, async (req, res) => {
  // Your expensive database query here
  const users = await db.collection("users").find({}).toArray();
  res.json(users);
});
```

### Example: Caching Database Queries

```javascript
async function getUserById(userId) {
  const cacheKey = `user:${userId}`;

  // Try to get from cache first
  const cached = await redisClient.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  // If not in cache, fetch from database
  const user = await db.collection("users").findOne({ _id: userId });

  // Store in cache for 1 hour
  await redisClient.setEx(cacheKey, 3600, JSON.stringify(user));

  return user;
}
```

## Deploy Redis

```powershell
# Apply Redis deployment
kubectl apply -f kubernetes/redis-cache.yaml

# Check Redis status
kubectl get pods -l app=redis

# Test Redis connection
kubectl exec -it deployment/redis-cache -- redis-cli ping
# Should return: PONG
```

## Redis Commands

```powershell
# Connect to Redis CLI
kubectl exec -it deployment/redis-cache -- redis-cli

# Common commands:
# PING                    - Test connection
# SET key value           - Set a value
# GET key                 - Get a value
# KEYS *                  - List all keys
# FLUSHALL                - Clear all cache
# INFO                    - Redis server info
```

## Cache Strategies

### 1. Cache-Aside (Lazy Loading)

- Check cache first
- If miss, load from database and cache it
- Good for read-heavy workloads

### 2. Write-Through

- Write to cache and database simultaneously
- Ensures cache is always up-to-date

### 3. Time-To-Live (TTL)

- Set expiration on cached data
- Prevents stale data

```javascript
// Set with TTL (seconds)
await redisClient.setEx("key", 300, "value"); // Expires in 5 minutes
```

## Monitoring Cache Performance

```javascript
// Track cache hit rate
let cacheHits = 0;
let cacheMisses = 0;

app.get("/api/cache-stats", (req, res) => {
  const hitRate = (cacheHits / (cacheHits + cacheMisses)) * 100;
  res.json({
    hits: cacheHits,
    misses: cacheMisses,
    hitRate: `${hitRate.toFixed(2)}%`,
  });
});
```

## Scaling Redis

For production, consider Redis with persistence or Redis Cluster:

```yaml
# Add persistence volume
volumes:
  - name: redis-data
    persistentVolumeClaim:
      claimName: redis-pvc
volumeMounts:
  - name: redis-data
    mountPath: /data
```
