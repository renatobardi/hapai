import { initializeApp } from 'firebase/app'
import {
  getAuth,
  GithubAuthProvider,
  signInWithPopup,
  signOut as firebaseSignOut,
  onAuthStateChanged,
} from 'firebase/auth'

const firebaseConfig = {
  apiKey:    import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'hapai-oute.firebaseapp.com',
  projectId:  import.meta.env.VITE_FIREBASE_PROJECT_ID  || 'hapai-oute',
  appId:      import.meta.env.VITE_FIREBASE_APP_ID,
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)

const provider = new GithubAuthProvider()

export async function signIn() {
  await signInWithPopup(auth, provider)
}

export async function signOut() {
  await firebaseSignOut(auth)
}

export { onAuthStateChanged }
