<script>
  import { signIn } from '../lib/firebase.js'
  import Logo from './Logo.svelte'
  let loading = $state(false)
  let error = $state('')
  async function go() { loading = true; error = ''; try { await signIn() } catch(e) { error = e.code === 'auth/popup-closed-by-user' ? '' : 'Sign in failed. Try again.' } finally { loading = false } }
</script>
<div class="gate">
  <div class="inner">
    <Logo size="lg" />
    <p class="desc">Deterministic guardrails analytics for AI coding assistants.</p>
    <button class="btn" onclick={go} disabled={loading}>
      {#if loading}Signing in…{:else}
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
        Sign in with GitHub
      {/if}
    </button>
    {#if error}<p class="error">{error}</p>{/if}
    <p class="note">Access restricted to authorized accounts.</p>
  </div>
</div>
<style>
  .gate { flex: 1; display: flex; align-items: center; justify-content: center; padding: var(--space-8) var(--space-3); }
  .inner { display: flex; flex-direction: column; align-items: center; gap: var(--space-3); max-width: 320px; width: 100%; text-align: center; }
  .desc { font-size: 14px; font-weight: var(--weight-light); color: var(--color-meta-gray); line-height: 1.5; }
  .btn { display: flex; align-items: center; justify-content: center; gap: var(--space-1); width: 100%; background: var(--color-near-black); color: #fff; padding: 14px 24px; font-size: 14px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.06em; transition: background 150ms; }
  .btn:hover:not(:disabled) { background: var(--color-blue); }
  .btn:disabled { background: var(--color-meta-gray); cursor: default; }
  .error { font-size: 12px; color: var(--color-deny); font-weight: var(--weight-bold); }
  .note { font-size: 11px; color: var(--color-light-gray); text-transform: uppercase; letter-spacing: 0.06em; }
</style>
