<script>
  import { authStore } from '../stores/auth.js'
  import { signIn, signOut } from '../lib/firebase.js'
  let signingIn = false
  async function handleSignIn() { signingIn = true; try { await signIn() } catch(e){} finally { signingIn = false } }
</script>
<header>
  <div class="brand">
    <span class="wordmark">hapai</span>
    <span class="subtitle">Guardrails Analytics</span>
  </div>
  <div class="actions">
    {#if !$authStore.loading && $authStore.user}
      <div class="user">
        {#if $authStore.user.photoURL}<img src={$authStore.user.photoURL} alt="" class="avatar" />{/if}
        <span class="username">{$authStore.user.displayName || $authStore.user.email}</span>
      </div>
      <button class="btn-secondary" on:click={signOut}>Sign out</button>
    {:else if !$authStore.loading}
      <button class="btn-primary" on:click={handleSignIn} disabled={signingIn}>
        {signingIn ? 'Signing in…' : 'Sign in with GitHub'}
      </button>
    {/if}
  </div>
</header>
<style>
  header { background: var(--color-black); height: 56px; padding: 0 var(--space-3); display: flex; align-items: center; justify-content: space-between; flex-shrink: 0; }
  .brand { display: flex; align-items: baseline; gap: var(--space-2); }
  .wordmark { font-size: 18px; font-weight: var(--weight-black); color: var(--color-white); letter-spacing: -0.01em; }
  .subtitle { font-size: 12px; font-weight: var(--weight-light); color: var(--color-meta-gray); }
  .actions { display: flex; align-items: center; gap: var(--space-2); }
  .user { display: flex; align-items: center; gap: var(--space-1); }
  .avatar { width: 28px; height: 28px; border-radius: 0; display: block; }
  .username { font-size: 13px; font-weight: var(--weight-bold); color: var(--color-white); }
  .btn-primary { background: var(--color-blue); color: #fff; padding: 8px 20px; font-size: 13px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em; transition: background 150ms; }
  .btn-primary:hover:not(:disabled) { background: var(--color-blue-dark); }
  .btn-primary:disabled { background: var(--color-meta-gray); cursor: default; }
  .btn-secondary { background: transparent; color: var(--color-meta-gray); padding: 8px 16px; font-size: 12px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em; border: 1px solid #333; transition: color 150ms, border-color 150ms; }
  .btn-secondary:hover { color: var(--color-white); border-color: #666; }
</style>
