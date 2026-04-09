<script>
  import { authStore } from './stores/auth.js'
  import { route, navigate } from './stores/route.js'
  import Header from './components/Header.svelte'
  import AuthGate from './components/AuthGate.svelte'
  import Dashboard from './components/Dashboard.svelte'
  import LoadingState from './components/LoadingState.svelte'
  import HowItWorksPage from './components/HowItWorksPage.svelte'
</script>
<div class="page">
  <Header />
  {#if $route.startsWith('#/docs')}
    <HowItWorksPage />
  {:else if $authStore.loading}
    <LoadingState message="Initializing…" />
  {:else if $authStore.user}
    <Dashboard />
  {:else}
    <AuthGate />
  {/if}
</div>
<style>
  :global(body){margin:0;}
  .page{min-height:100vh;display:flex;flex-direction:column;}
</style>
