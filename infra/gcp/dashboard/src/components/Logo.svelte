<script>
  export let size = 'sm'
</script>

{#if size === 'sm'}
  <div class="logo-sm">
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

  .logo-sm .dashes { display: flex; flex-direction: column; gap: 3px; }
  .logo-sm .dash { height: 4px; width: 20px; background: var(--color-near-black); }
  .logo-sm .dash:nth-child(2) { width: 30px; }
  .logo-sm .dash:nth-child(3) { width: 25px; }
  .logo-sm .bar { height: 20px; width: 4px; background: var(--color-cyan); margin: 0 6px; }
  .logo-sm .text { font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: 18px; color: var(--color-white); letter-spacing: -0.01em; }

  .logo-lg .dashes { display: flex; flex-direction: column; gap: 5px; }
  .logo-lg .dash { height: 6px; width: 25px; background: var(--color-near-black); }
  .logo-lg .dash:nth-child(2) { width: 45px; }
  .logo-lg .dash:nth-child(3) { width: 35px; }
  .logo-lg .bar { height: 90px; width: 6px; background: var(--color-cyan); margin: 0 12px; }
  .logo-lg .text { font-family: 'Space Grotesk', sans-serif; font-weight: 700; font-size: 56px; color: var(--color-near-black); letter-spacing: -0.03em; line-height: 1; }
</style>
