import { defineConfig } from 'vite';

// SvelteKit handles Vite configuration automatically
// This is only needed if you need custom Vite options
export default defineConfig({
  server: {
    port: 3000,
    host: '0.0.0.0',
  },
  build: {
    target: 'es2020',
  },
});
