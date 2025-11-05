// Anonymization and import script for Test DB
db = db.getSiblingDB('myapp');

// Drop existing data
print('Clearing test database...');
db.dropDatabase();

// Use the same database again
db = db.getSiblingDB('myapp');

// Define anonymized users
var anonymizedUsers = [
  {
    username: 'testuser_5ce5f47',
    email: 'testuser_5ce5f47@example.com',
    password: 'TestPassword123!',
    firstName: 'TestFirst',
    lastName: 'TestLast',
    role: 'admin',
    phoneNumber: '+1-555-TEST',
    address: '123 Test St, Test City, TS 00000'
  },
  {
    username: 'testuser_5ce5f48',
    email: 'testuser_5ce5f48@example.com',
    password: 'TestPassword123!',
    firstName: 'TestFirst',
    lastName: 'TestLast',
    role: 'user',
    phoneNumber: '+1-555-TEST',
    address: '123 Test St, Test City, TS 00000'
  },
  {
    username: 'testuser_5ce5f49',
    email: 'testuser_5ce5f49@example.com',
    password: 'TestPassword123!',
    firstName: 'TestFirst',
    lastName: 'TestLast',
    role: 'user',
    phoneNumber: '+1-555-TEST',
    address: '123 Test St, Test City, TS 00000'
  },
  {
    username: 'testuser_5ce5f4a',
    email: 'testuser_5ce5f4a@example.com',
    password: 'TestPassword123!',
    firstName: 'TestFirst',
    lastName: 'TestLast',
    role: 'manager',
    phoneNumber: '+1-555-TEST',
    address: '123 Test St, Test City, TS 00000'
  },
  {
    username: 'testuser_5ce5f4b',
    email: 'testuser_5ce5f4b@example.com',
    password: 'TestPassword123!',
    firstName: 'TestFirst',
    lastName: 'TestLast',
    role: 'user',
    phoneNumber: '+1-555-TEST',
    address: '123 Test St, Test City, TS 00000'
  }
];

print('Inserting ' + anonymizedUsers.length + ' anonymized users...');
var result = db.users.insertMany(anonymizedUsers);
print('Inserted ' + Object.keys(result.insertedIds).length + ' users');

print('\nVerification:');
print('Total users in test: ' + db.users.countDocuments());
print('\nSample anonymized user:');
printjson(db.users.findOne({}, {password: 0}));
