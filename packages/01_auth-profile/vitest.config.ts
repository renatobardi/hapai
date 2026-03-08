import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    // Exclude E2E tests from Vitest - they should be run with Playwright CLI
    exclude: [
      'node_modules',
      'dist',
      'build',
      '.idea',
      '.git',
      '.cache',
      'src/**/*.spec.ts', // Playwright specs (*.spec.ts)
      'src/**/*.e2e.ts',  // E2E test files
    ],
    include: ['src/**/*.test.ts'], // Only include unit tests (*.test.ts)
  },
});
