<script>
  let { title = '', accent = '', children } = $props()
</script>
<div class="card" style:border-top-color={accent ? `var(--color-${accent})` : 'var(--color-light-gray)'}>
  {#if title}<div class="card-title">{title}</div>{/if}
  {@render children?.()}
</div>
