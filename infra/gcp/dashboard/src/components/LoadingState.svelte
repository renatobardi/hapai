<script>export let message = 'Loading…'</script>
<div class="loading"><div class="spinner"></div><p>{message}</p></div>
<style>
  .loading { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: var(--space-2); padding: var(--space-8); color: var(--color-meta-gray); font-size: 13px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.06em; }
  .spinner { width: 32px; height: 32px; border: 2px solid var(--color-light-gray); border-top-color: var(--color-blue); animation: spin 600ms linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
