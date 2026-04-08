<script>
  import { authStore } from './stores/auth.js'
  import Header from './components/Header.svelte'
  import AuthGate from './components/AuthGate.svelte'
  import Dashboard from './components/Dashboard.svelte'
  import LoadingState from './components/LoadingState.svelte'
</script>

<div class="page">
  {#if !$authStore.configured}
    <Header />
    <div class="setup-notice">
      <div class="inner">
        <div class="tag">Setup required</div>
        <h2>Firebase not configured</h2>
        <p>Set <code>VITE_FIREBASE_API_KEY</code> and <code>VITE_FIREBASE_APP_ID</code> in your <code>.env</code> file or as GitHub Actions secrets to enable authentication.</p>
        <pre>VITE_FIREBASE_API_KEY=...{'\n'}VITE_FIREBASE_APP_ID=...{'\n'}VITE_BQ_PROXY_URL=...</pre>
      </div>
    </div>
  {:else if $authStore.loading}
    <LoadingState message="Initializing…" />
  {:else}
    <Header />
    {#if $authStore.user}
      <Dashboard />
    {:else}
      <AuthGate />
    {/if}
  {/if}
</div>

<style>
  :global(body) { margin: 0; }

  .page {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }

  .setup-notice {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-8) var(--space-3);
  }

  .inner {
    max-width: 480px;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .tag {
    font-size: 11px;
    font-weight: var(--weight-bold);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--color-warn);
  }

  h2 {
    font-size: 24px;
    font-weight: var(--weight-black);
    color: var(--color-near-black);
    margin: 0;
  }

  p {
    font-size: 14px;
    color: var(--color-meta-gray);
    line-height: 1.6;
  }

  code {
    font-family: 'SF Mono', 'Fira Code', Consolas, monospace;
    font-size: 12px;
    background: var(--color-light-gray);
    padding: 2px 5px;
    color: var(--color-near-black);
  }

  pre {
    font-family: 'SF Mono', 'Fira Code', Consolas, monospace;
    font-size: 12px;
    background: var(--color-near-black);
    color: #a8d8a8;
    padding: var(--space-2) var(--space-3);
    margin: 0;
    line-height: 1.8;
  }
</style>
