import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  plugins: [svelte()],
  base: '/hapai/',
  build: {
    outDir: '../../../_site',
    emptyOutDir: true,
  },
})
