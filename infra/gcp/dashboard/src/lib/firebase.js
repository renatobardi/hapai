import { initializeApp } from 'firebase/app'
import { getAuth, GithubAuthProvider, signInWithPopup, signOut as fbSignOut, onAuthStateChanged } from 'firebase/auth'

const app = initializeApp({
  apiKey:    import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'hapai-oute.firebaseapp.com',
  projectId:  import.meta.env.VITE_FIREBASE_PROJECT_ID  || 'hapai-oute',
  appId:      import.meta.env.VITE_FIREBASE_APP_ID,
})
export const auth = getAuth(app)
const provider = new GithubAuthProvider()
export const signIn  = () => signInWithPopup(auth, provider)
export const signOut = () => fbSignOut(auth)
export { onAuthStateChanged }
