<script>
  import { authStore } from './stores/auth.js'
  import Header from './components/Header.svelte'
  import AuthGate from './components/AuthGate.svelte'
  import Dashboard from './components/Dashboard.svelte'
  import LoadingState from './components/LoadingState.svelte'
  import HowItWorksPage from './components/HowItWorksPage.svelte'
  let currentHash = $state(typeof window !== 'undefined' ? window.location.hash : '')
  $effect(() => {
    if (typeof window === 'undefined') return
    const onHash = () => { currentHash = window.location.hash }
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  })
</script>
<div class="page">
  {#if $authStore.loading}
    <LoadingState message="Initializing…" />
  {:else}
    <Header />
    {#if currentHash === '#/docs'}
      <HowItWorksPage />
    {:else if $authStore.user}
      <Dashboard />
    {:else}
      <AuthGate />
    {/if}
  {/if}
</div>
<style>
  :global(body){margin:0;}
  .page{min-height:100vh;display:flex;flex-direction:column;}
</style>
