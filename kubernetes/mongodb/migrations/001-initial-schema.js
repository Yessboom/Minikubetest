// Migration 001: Initial Schema Setup
// This migration creates the initial database structure with collections and indexes
// Sharding is enabled and configured for scalability

db = db.getSiblingDB('myapp');

function up() {
  print('=== Migration 001: Initial Schema Setup ===');
  
  // Create users collection
  print('Creating users collection...');
  db.createCollection('users');
  
  // Create indexes on users
  print('Creating indexes on users...');
  db.users.createIndex({ email: 1 }, { unique: true, name: 'email_unique' });
  db.users.createIndex({ username: 1 }, { unique: true, name: 'username_unique' });
  db.users.createIndex({ createdAt: -1 }, { name: 'created_at_desc' });
  
  // Create items collection
  print('Creating items collection...');
  db.createCollection('items');
  
  // Create indexes on items
  print('Creating indexes on items...');
  db.items.createIndex({ userId: 1 }, { name: 'user_id' });
  db.items.createIndex({ name: 1 }, { name: 'item_name' });
  db.items.createIndex({ createdAt: -1 }, { name: 'created_at_desc' });
  db.items.createIndex({ userId: 1, createdAt: -1 }, { name: 'user_created_compound' });
  
  // Create orders collection (for potential future use)
  print('Creating orders collection...');
  db.createCollection('orders');
  
  // Create indexes on orders
  print('Creating indexes on orders...');
  db.orders.createIndex({ userId: 1 }, { name: 'user_id' });
  db.orders.createIndex({ status: 1 }, { name: 'status' });
  db.orders.createIndex({ orderDate: -1 }, { name: 'order_date_desc' });
  db.orders.createIndex({ userId: 1, orderDate: -1 }, { name: 'user_order_date' });
  
  // Enable sharding for the database
  print('Enabling sharding for myapp database...');
  sh.enableSharding("myapp");
  
  // Shard the users collection by hashed _id for even distribution
  print('Sharding users collection...');
  sh.shardCollection("myapp.users", { _id: "hashed" });
  
  // Shard the items collection by userId for co-location with user queries
  print('Sharding items collection...');
  sh.shardCollection("myapp.items", { userId: 1, _id: 1 });
  
  // Shard the orders collection
  print('Sharding orders collection...');
  sh.shardCollection("myapp.orders", { userId: 1, orderDate: 1 });
  
  // Create migrations tracking collection (not sharded, metadata)
  print('Creating migrations tracking collection...');
  db.createCollection('migrations');
  db.migrations.createIndex({ migration: 1 }, { unique: true, name: 'migration_unique' });
  
  // Insert sample data for testing
  print('Inserting sample data...');
  db.users.insertOne({
    username: 'admin',
    email: 'admin@example.com',
    passwordHash: '$2b$10$abcdefghijklmnopqrstuv', // bcrypt hash placeholder
    role: 'admin',
    createdAt: new Date(),
    updatedAt: new Date()
  });
  
  db.users.insertOne({
    username: 'testuser',
    email: 'test@example.com',
    passwordHash: '$2b$10$abcdefghijklmnopqrstuv',
    role: 'user',
    createdAt: new Date(),
    updatedAt: new Date()
  });
  
  // Get the test user id for sample items
  var testUser = db.users.findOne({ username: 'testuser' });
  
  db.items.insertMany([
    {
      userId: testUser._id,
      name: 'Sample Item 1',
      description: 'This is a test item',
      quantity: 10,
      price: 19.99,
      createdAt: new Date(),
      updatedAt: new Date()
    },
    {
      userId: testUser._id,
      name: 'Sample Item 2',
      description: 'Another test item',
      quantity: 5,
      price: 29.99,
      createdAt: new Date(),
      updatedAt: new Date()
    }
  ]);
  
  // Track this migration
  db.migrations.insertOne({
    migration: '001-initial-schema',
    description: 'Initial schema with users, items, orders collections and sharding',
    executed_at: new Date(),
    status: 'completed',
    version: '1.0.0'
  });
  
  print('=== Migration 001: Completed Successfully ===');
  print('Collections created: users, items, orders, migrations');
  print('Sharding enabled for: users (hashed _id), items (userId, _id), orders (userId, orderDate)');
  print('Sample users created: admin, testuser');
  print('Sample items created: 2 items');
}

function down() {
  print('=== Migration 001: Rollback ===');
  
  // Drop collections
  db.users.drop();
  db.items.drop();
  db.orders.drop();
  
  // Remove migration record
  db.migrations.deleteOne({ migration: '001-initial-schema' });
  
  print('=== Migration 001: Rolled Back ===');
}

// Execute the migration
up();
