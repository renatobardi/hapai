<script>
  export let size = 'sm'
  export let dark = false
</script>

{#if size === 'sm'}
  <img
    src={dark ? '/hapai/logo-light.png' : '/hapai/logo-dark.png'}
    alt="hapai"
    class="logo-sm"
  />
{:else if size === 'lg'}
  <img
    src={dark ? '/hapai/logo-light.png' : '/hapai/logo-dark.png'}
    alt="hapai"
    class="logo-lg"
  />
{/if}

<style>
  .logo-sm { height: 24px; width: auto; display: block; }
  .logo-lg { height: 96px; width: auto; display: block; }
</style>
