<script>
  export let title = ''
  export let accent = ''
</script>
<div class="card" style:border-top-color={accent ? `var(--color-${accent})` : 'var(--color-light-gray)'}>
  {#if title}<div class="card-title">{title}</div>{/if}
  <slot />
</div>
