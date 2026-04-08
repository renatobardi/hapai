import { initializeApp } from 'firebase/app'
import {
  getAuth,
  GithubAuthProvider,
  signInWithPopup,
  signOut as firebaseSignOut,
  onAuthStateChanged,
} from 'firebase/auth'

const apiKey = import.meta.env.VITE_FIREBASE_API_KEY

export const configured = !!apiKey

const firebaseConfig = {
  apiKey,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'hapai-oute.firebaseapp.com',
  projectId:  import.meta.env.VITE_FIREBASE_PROJECT_ID  || 'hapai-oute',
  appId:      import.meta.env.VITE_FIREBASE_APP_ID,
}

// Only initialize Firebase when credentials are present
const app  = configured ? initializeApp(firebaseConfig) : null
export const auth = configured ? getAuth(app) : null

const provider = configured ? new GithubAuthProvider() : null

export async function signIn() {
  if (!auth) throw new Error('Firebase not configured')
  await signInWithPopup(auth, provider)
}

export async function signOut() {
  if (!auth) return
  await firebaseSignOut(auth)
}

export { onAuthStateChanged }
