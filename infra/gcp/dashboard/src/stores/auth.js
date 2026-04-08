import { writable } from 'svelte/store'
import { auth, onAuthStateChanged } from '../lib/firebase.js'

export const authStore = writable({ user: null, idToken: null, loading: true })

onAuthStateChanged(auth, async (user) => {
  if (user) {
    const idToken = await user.getIdToken()
    authStore.set({ user, idToken, loading: false })
  } else {
    authStore.set({ user: null, idToken: null, loading: false })
  }
})
