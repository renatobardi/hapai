<script>
  import { authStore } from '../stores/auth.js'
  import { signIn, signOut } from '../lib/firebase.js'
  import { route, navigate } from '../stores/route.js'
  import Logo from './Logo.svelte'
  let signingIn = $state(false)
  async function handleSignIn() { signingIn = true; try { await signIn() } catch(e){} finally { signingIn = false } }
</script>
<header>
  <div class="brand">
    <Logo size="sm" dark={true} />
    <span class="subtitle">Guardrails Analytics</span>
  </div>
  <nav class="nav">
    {#if $authStore.user}
      <a href="#/" class="nav-link" class:active={$route === '' || $route === '#/' || !$route.startsWith('#/docs')} onclick={(e) => { e.preventDefault(); navigate('#/') }}>Dashboard</a>
    {/if}
    <a href="#/docs" class="nav-link" class:active={$route.startsWith('#/docs')} onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>How it works</a>
  </nav>
  <div class="actions">
    {#if !$authStore.loading && $authStore.user}
      <div class="user">
        {#if $authStore.user.photoURL}<img src={$authStore.user.photoURL} alt="" class="avatar" />{/if}
        <span class="username">{$authStore.user.displayName || $authStore.user.email}</span>
      </div>
      <button class="btn-secondary" onclick={signOut}>Sign out</button>
    {:else if !$authStore.loading}
      <button class="btn-primary" onclick={handleSignIn} disabled={signingIn}>
        {signingIn ? 'Signing in…' : ''}
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
        {!signingIn && 'Sign in with GitHub'}
      </button>
    {/if}
  </div>
</header>
<style>
  header { background: var(--color-black); height: 80px; padding: 0 var(--space-3); display: flex; align-items: center; justify-content: space-between; flex-shrink: 0; position: relative; }
  .brand { display: flex; flex-direction: column; align-items: flex-start; gap: 2px; }
  .subtitle { font-size: 18px; font-weight: var(--weight-light); color: #e8e8e8; line-height: 1; }
  .nav { display: flex; align-items: center; gap: var(--space-3); }
  .nav-link { font-size: 12px; font-weight: var(--weight-bold); color: var(--color-meta-gray); text-decoration: none; text-transform: uppercase; letter-spacing: 0.05em; transition: color 150ms; }
  .nav-link:hover { color: var(--color-white); }
  .nav-link.active { color: var(--color-white); }
  .actions { display: flex; align-items: center; gap: var(--space-2); }
  .user { display: flex; align-items: center; gap: var(--space-1); }
  .avatar { width: 28px; height: 28px; border-radius: 0; display: block; }
  .username { font-size: 13px; font-weight: var(--weight-bold); color: var(--color-white); }
  .btn-primary { background: var(--color-blue); color: #fff; padding: 8px 20px; font-size: 13px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em; transition: background 150ms; display: flex; align-items: center; gap: var(--space-1); }
  .btn-primary svg { display: block; width: 16px; height: 16px; }
  .btn-primary:hover:not(:disabled) { background: var(--color-blue-dark); }
  .btn-primary:disabled { background: var(--color-meta-gray); cursor: default; }
  .btn-secondary { background: transparent; color: var(--color-meta-gray); padding: 8px 16px; font-size: 12px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em; border: 1px solid #333; transition: color 150ms, border-color 150ms; }
  .btn-secondary:hover { color: var(--color-white); border-color: #666; }
</style>
