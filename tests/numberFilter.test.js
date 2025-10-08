const filterEvenNumbers = require('../numberFilter');

test('Filter even numbers', () => {
  const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  const filteredNumbers = filterEvenNumbers(numbers);
  expect(filteredNumbers).toEqual([2, 4, 6, 8, 10]);
});

test('Filter even numbers in an empty array', () => {
  const numbers = [];
  const filteredNumbers = filterEvenNumbers(numbers);
  expect(filteredNumbers).toEqual([]);
});

test('Filter even numbers in an array with no even numbers', () => {
  const numbers = [1, 3, 5, 7, 9];
  const filteredNumbers = filterEvenNumbers(numbers);
  expect(filteredNumbers).toEqual([]);
});

test('Filter even numbers in an array with all even numbers', () => {
  const numbers = [2, 4, 6, 8, 10];
  const filteredNumbers = filterEvenNumbers(numbers);
  expect(filteredNumbers).toEqual([2, 4, 6, 8, 10]);
});

test('Filter even and odd numbers', () => {
  const numbers = [1, 2, 3, 4, 5];
  const filteredNumbers = filterEvenNumbers(numbers);
  expect(filteredNumbers).toEqual([2, 4]);
});

test("This is a failed test that is now working to check the CI/CD pipeline", () => {
    const numbers = [1, 2, 3];
    const filteredNumbers = filterEvenNumbers(numbers);
    expect(filteredNumbers).toEqual([1, 2]);
});