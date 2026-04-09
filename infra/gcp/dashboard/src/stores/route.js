import { writable } from 'svelte/store'

export const route = writable(typeof window !== 'undefined' ? window.location.hash : '')

export function navigate(hash) {
  window.location.hash = hash
  route.set(hash)
}

if (typeof window !== 'undefined') {
  window.addEventListener('hashchange', () => {
    route.set(window.location.hash)
  })
}
