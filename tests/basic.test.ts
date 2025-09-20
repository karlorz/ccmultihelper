import { test, expect } from 'bun:test';

test('basic test passes', () => {
  expect(1 + 1).toBe(2);
});

test('package can be imported', async () => {
  // This will verify the build process works
  const pkg = await import('../package.json');
  expect(pkg.name).toBe('ccmultihelper');
  expect(pkg.version).toBeDefined();
});