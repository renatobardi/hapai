<script>
  import { authStore } from './stores/auth.js'
  import Header from './components/Header.svelte'
  import AuthGate from './components/AuthGate.svelte'
  import Dashboard from './components/Dashboard.svelte'
  import LoadingState from './components/LoadingState.svelte'
</script>
<div class="page">
  {#if $authStore.loading}
    <LoadingState message="Initializing…" />
  {:else}
    <Header />
    {#if $authStore.user}<Dashboard />{:else}<AuthGate />{/if}
  {/if}
</div>
<style>
  :global(body){margin:0;}
  .page{min-height:100vh;display:flex;flex-direction:column;}
</style>
