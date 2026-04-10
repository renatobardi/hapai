<script>
  import { authStore } from '../stores/auth.js'
  import { signIn, signOut } from '../lib/firebase.js'
  import { route, navigate } from '../stores/route.js'
  import { t, locale, setLocale } from '../stores/i18n.js'
  import Logo from './Logo.svelte'
  import Button from './Button.svelte'
  let signingIn = $state(false)
  let signInError = $state('')
  async function handleSignIn() {
    signingIn = true; signInError = ''
    try { await signIn() } catch(e) {
      if (e.code !== 'auth/popup-closed-by-user') signInError = $t('header.auth.signInError')
    } finally { signingIn = false }
  }
</script>
<header>
  <div class="brand">
    <Logo size="sm" dark={true} />
    <span class="subtitle">{$t('header.subtitle')}</span>
  </div>
  <nav class="nav">
    {#if $authStore.user}
      <a href="#/" class="nav-link" class:active={$route === '' || $route === '#/'} onclick={(e) => { e.preventDefault(); navigate('#/') }}>{$t('header.nav.dashboard')}</a>
    {/if}
    <a href="#/docs" class="nav-link" class:active={$route.startsWith('#/docs')} onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>{$t('header.nav.docs')}</a>
  </nav>
  <div class="lang-switcher" aria-label="Language">
    <button class:active={$locale === 'en'}    onclick={() => setLocale('en')}>EN</button>
    <button class:active={$locale === 'pt-BR'} onclick={() => setLocale('pt-BR')}>PT</button>
    <button class:active={$locale === 'es-ES'} onclick={() => setLocale('es-ES')}>ES</button>
  </div>
  <div class="actions">
    {#if !$authStore.loading && $authStore.user}
      <div class="user">
        {#if $authStore.user.photoURL}<img src={$authStore.user.photoURL} alt="" class="avatar" />{/if}
        <span class="username">{$authStore.user.displayName || $authStore.user.email}</span>
      </div>
      <Button variant="secondary" onclick={signOut}>{$t('header.auth.signOut')}</Button>
    {:else if !$authStore.loading}
      <Button onclick={handleSignIn} disabled={signingIn}>
        {signingIn ? $t('header.auth.signingIn') : ''}
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
        {!signingIn && $t('header.auth.signIn')}
      </Button>
      {#if signInError}<p class="signin-error">{signInError}</p>{/if}
    {/if}
  </div>
</header>
<style>
  header { background: var(--color-black); height: 80px; padding: 0 var(--space-3); display: flex; align-items: center; justify-content: space-between; flex-shrink: 0; position: relative; }
  .brand { display: flex; flex-direction: column; align-items: flex-start; gap: 2px; }
  .subtitle { font-size: 18px; font-weight: var(--weight-light); color: var(--color-text-on-dark); line-height: 1; }
  .nav { display: flex; align-items: center; gap: var(--space-3); }
  .nav-link { font-size: 12px; font-weight: var(--weight-bold); color: var(--color-meta-gray); text-decoration: none; text-transform: uppercase; letter-spacing: 0.05em; transition: color 150ms; }
  .nav-link:hover { color: var(--color-white); }
  .nav-link.active { color: var(--color-white); }
  .lang-switcher { display: flex; align-items: center; gap: 4px; }
  .lang-switcher button { background: transparent; color: var(--color-meta-gray); border: none; padding: 4px 6px; font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em; cursor: pointer; transition: color 150ms; }
  .lang-switcher button:hover { color: var(--color-white); }
  .lang-switcher button.active { color: var(--color-white); }
  .actions { display: flex; align-items: center; gap: var(--space-2); }
  .user { display: flex; align-items: center; gap: var(--space-1); }
  .avatar { width: 28px; height: 28px; border-radius: 0; display: block; }
  .username { font-size: 13px; font-weight: var(--weight-bold); color: var(--color-white); }
  .signin-error { font-size: 11px; color: var(--color-deny); margin: 4px 0 0; text-align: right; }
</style>
