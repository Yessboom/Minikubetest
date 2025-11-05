#!/bin/bash

# MongoDB Schema Migration Framework
# This directory contains versioned migration scripts for your MongoDB databases
# Migrations run sequentially and track completion in a 'migrations' collection

# Directory structure:
# migrations/
#   ├── 001-initial-schema.js
#   ├── 002-add-indexes.js
#   ├── 003-update-documents.js
#   └── README.md (this file)

# Migration format:
# Each .js file should contain two functions:
# 1. up() - applies the migration
# 2. down() - reverts the migration

# Example migration file (001-initial-schema.js):
# 
# db = db.getSiblingDB('myapp');
# 
# function up() {
#   db.users.insertMany([
#     { username: 'admin', email: 'admin@example.com', created: new Date() }
#   ]);
#   db.users.createIndex({ username: 1 }, { unique: true });
#   print('Migration 001: Created users collection');
# }
# 
# function down() {
#   db.users.drop();
#   print('Migration 001: Dropped users collection');
# }
# 
# up();

# Running migrations:
# kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < 001-initial-schema.js
