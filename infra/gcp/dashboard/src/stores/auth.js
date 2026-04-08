import { writable } from 'svelte/store'
import { auth, onAuthStateChanged, configured } from '../lib/firebase.js'

export const authStore = writable({ user: null, idToken: null, loading: !configured, configured })

if (configured) {
  onAuthStateChanged(auth, async (user) => {
    if (user) {
      const idToken = await user.getIdToken()
      authStore.set({ user, idToken, loading: false, configured })
    } else {
      authStore.set({ user: null, idToken: null, loading: false, configured })
    }
  })
}
