<script>
  let { type = 'info', children } = $props()
</script>
<span class="badge badge-{type}">{@render children?.()}</span>
