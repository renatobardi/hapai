// SvelteKit hooks and initialization

import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Add any global middleware here
  const response = await resolve(event);
  return response;
};
