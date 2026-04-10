<script>
  import { authStore } from './stores/auth.js'
  import { route } from './stores/route.js'
  import Header from './components/Header.svelte'
  import LandingPage from './components/LandingPage.svelte'
  import Dashboard from './components/Dashboard.svelte'
  import LoadingState from './components/LoadingState.svelte'
  import HowItWorksPage from './components/HowItWorksPage.svelte'
  import { t } from './stores/i18n.js'
</script>
<div class="page">
  <Header />
  {#if $route.startsWith('#/docs')}
    <HowItWorksPage />
  {:else if $authStore.loading}
    <LoadingState message={$t('app.initializing')} />
  {:else if $authStore.user}
    <Dashboard />
  {:else}
    <LandingPage />
  {/if}
</div>
<style>
  :global(body){margin:0;}
  .page{min-height:100vh;display:flex;flex-direction:column;}
</style>
