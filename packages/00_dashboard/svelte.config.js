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
      '@hapai/design-system': '../../packages/design-system/src',
      '@hapai/shared': '../../shared',
    },
  },
};

export default config;
