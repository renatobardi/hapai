<script>
  let { message = '' } = $props()
</script>
<p class="empty-state">{message}</p>
<style>
  .empty-state {
    font-size: 13px; color: var(--color-meta-gray);
    text-align: center; padding: var(--space-4) var(--space-3);
    line-height: 1.6;
  }
</style>
