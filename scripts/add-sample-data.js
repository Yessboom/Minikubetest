// Add sample users to production database
db = db.getSiblingDB('myapp');

// Insert sample users with passwords
db.users.insertMany([
  {
    username: 'john.doe',
    email: 'john.doe@company.com',
    password: 'SecurePass123!',
    firstName: 'John',
    lastName: 'Doe',
    role: 'admin',
    phoneNumber: '+1-555-0101',
    address: '123 Main St, New York, NY 10001',
    createdAt: new Date()
  },
  {
    username: 'jane.smith',
    email: 'jane.smith@company.com',
    password: 'MySecret456!',
    firstName: 'Jane',
    lastName: 'Smith',
    role: 'user',
    phoneNumber: '+1-555-0102',
    address: '456 Oak Ave, Los Angeles, CA 90001',
    createdAt: new Date()
  },
  {
    username: 'bob.wilson',
    email: 'bob.wilson@company.com',
    password: 'BobPass789!',
    firstName: 'Bob',
    lastName: 'Wilson',
    role: 'user',
    phoneNumber: '+1-555-0103',
    address: '789 Pine Rd, Chicago, IL 60601',
    createdAt: new Date()
  },
  {
    username: 'alice.johnson',
    email: 'alice.johnson@company.com',
    password: 'AliceSecure!',
    firstName: 'Alice',
    lastName: 'Johnson',
    role: 'manager',
    phoneNumber: '+1-555-0104',
    address: '321 Elm St, Houston, TX 77001',
    createdAt: new Date()
  },
  {
    username: 'charlie.brown',
    email: 'charlie.brown@company.com',
    password: 'CharliePass!',
    firstName: 'Charlie',
    lastName: 'Brown',
    role: 'user',
    phoneNumber: '+1-555-0105',
    address: '654 Maple Dr, Phoenix, AZ 85001',
    createdAt: new Date()
  }
]);

print('Inserted users successfully!');
print('Total users: ' + db.users.countDocuments());
db.users.find({}, {password: 0});
