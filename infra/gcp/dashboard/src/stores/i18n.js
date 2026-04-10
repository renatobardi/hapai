import { writable, derived } from 'svelte/store'
import en from '../lib/locales/en.js'
import ptBR from '../lib/locales/pt-BR.js'
import esES from '../lib/locales/es-ES.js'

const locales = { en, 'pt-BR': ptBR, 'es-ES': esES }
const supported = Object.keys(locales)

function detect() {
  if (typeof localStorage !== 'undefined') {
    const saved = localStorage.getItem('hapai-lang')
    if (saved && supported.includes(saved)) return saved
  }
  if (typeof navigator !== 'undefined') {
    const full = navigator.language || ''
    if (supported.includes(full)) return full
    const match = supported.find(l => l.startsWith(full.split('-')[0]))
    if (match) return match
  }
  return 'en'
}

export const locale = writable(detect())

export function setLocale(lang) {
  if (!supported.includes(lang)) return
  locale.set(lang)
  if (typeof localStorage !== 'undefined') localStorage.setItem('hapai-lang', lang)
}

// Usage: $t('header.nav.docs') → translated string
// In non-reactive context: import { get } from 'svelte/store'; get(t)('key')
export const t = derived(locale, ($locale) => {
  const msgs = locales[$locale] ?? locales.en
  return (key) => {
    const parts = key.split('.')
    let val = msgs
    for (const p of parts) val = val?.[p]
    return val ?? key
  }
})
