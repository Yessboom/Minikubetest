// Migration 001: Initialize Collections and Indexes
// This migration creates the initial schema for the application

db = db.getSiblingDB('myapp');

function up() {
  print('Starting migration 001: Initial schema setup');
  
  // Create users collection with schema validation
  db.createCollection('users', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['username', 'email', 'created'],
        properties: {
          _id: { bsonType: 'objectId' },
          username: { bsonType: 'string', minLength: 3, maxLength: 50 },
          email: { bsonType: 'string' },
          password_hash: { bsonType: 'string' },
          status: { enum: ['active', 'inactive', 'suspended'], default: 'active' },
          created: { bsonType: 'date' },
          updated: { bsonType: 'date' }
        }
      }
    }
  });
  
  // Create indexes for users collection
  db.users.createIndex({ username: 1 }, { unique: true });
  db.users.createIndex({ email: 1 }, { unique: true });
  db.users.createIndex({ created: 1 });
  
  // Create items collection
  db.createCollection('items', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['name', 'user_id', 'created'],
        properties: {
          _id: { bsonType: 'objectId' },
          name: { bsonType: 'string' },
          description: { bsonType: 'string' },
          user_id: { bsonType: 'objectId' },
          category: { bsonType: 'string' },
          status: { enum: ['active', 'archived'], default: 'active' },
          created: { bsonType: 'date' },
          updated: { bsonType: 'date' }
        }
      }
    }
  });
  
  // Create indexes for items collection
  db.items.createIndex({ user_id: 1 });
  db.items.createIndex({ category: 1 });
  db.items.createIndex({ created: 1 });
  
  // Track migration
  db.migrations.insertOne({
    migration: '001-initial-schema',
    executed_at: new Date(),
    status: 'completed'
  });
  
  print('Migration 001: Completed successfully');
}

function down() {
  print('Reverting migration 001');
  db.users.drop();
  db.items.drop();
  db.migrations.deleteOne({ migration: '001-initial-schema' });
  print('Migration 001: Reverted successfully');
}

// Execute migration
up();
