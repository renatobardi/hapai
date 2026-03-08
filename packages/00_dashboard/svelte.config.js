import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      out: 'build',
      precompress: false,
    }),
    alias: {
      '$lib': 'src/lib',
      '@oute/design-system': '../../packages/design-system/src',
      '@oute/shared': '../../shared',
    },
  },
};

export default config;
