import { writable } from 'svelte/store'

export const route = writable(typeof window !== 'undefined' ? window.location.hash : '')

export function navigate(hash) {
  if (typeof window !== 'undefined') window.location.hash = hash
  route.set(hash)
}

if (typeof window !== 'undefined') {
  const handler = () => route.set(window.location.hash)
  window.addEventListener('hashchange', handler)

  if (import.meta.hot) {
    import.meta.hot.dispose(() => window.removeEventListener('hashchange', handler))
  }
}
