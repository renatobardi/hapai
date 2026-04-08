<script>
  export let size = 'sm'
  export let dark = false
</script>

{#if size === 'sm'}
  <div class="logo-sm" class:dark>
    <div class="dashes">
      <div class="dash"></div>
      <div class="dash"></div>
      <div class="dash"></div>
    </div>
    <div class="bar"></div>
    <div class="text">hapai</div>
  </div>
{:else if size === 'lg'}
  <div class="logo-lg">
    <div class="dashes">
      <div class="dash"></div>
      <div class="dash"></div>
      <div class="dash"></div>
    </div>
    <div class="bar"></div>
    <div class="text">hapai</div>
  </div>
{/if}

<style>
  .logo-sm, .logo-lg { display: flex; align-items: center; gap: 0; }

  .logo-sm .dashes { display: flex; flex-direction: column; gap: 2px; }
  .logo-sm .dash { height: 3px; width: 16px; background: var(--color-white); }
  .logo-sm .dash:nth-child(2) { width: 22px; }
  .logo-sm .dash:nth-child(3) { width: 19px; }
  .logo-sm .bar { height: 18px; width: 3px; background: var(--color-cyan); margin: 0 5px; }
  .logo-sm .text { font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: 18px; color: var(--color-white); letter-spacing: -0.01em; }

  .logo-sm.dark .dash { background: var(--color-near-black); }
  .logo-sm.dark .text { color: var(--color-near-black); }

  .logo-lg .dashes { display: flex; flex-direction: column; gap: 4px; }
  .logo-lg .dash { height: 5px; width: 30px; background: var(--color-near-black); }
  .logo-lg .dash:nth-child(2) { width: 50px; }
  .logo-lg .dash:nth-child(3) { width: 40px; }
  .logo-lg .bar { height: 80px; width: 5px; background: var(--color-cyan); margin: 0 10px; }
  .logo-lg .text { font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: 56px; color: var(--color-near-black); letter-spacing: -0.03em; line-height: 1; }
</style>
