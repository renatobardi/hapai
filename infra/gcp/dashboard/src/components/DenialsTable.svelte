<script>
  export let data = []
  const fmt = ts => new Date(ts).toLocaleString(undefined, {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'})
</script>
<div class="card">
  <div class="card-title">Recent Events</div>
  {#if !data.length}<p class="empty">No events found.</p>
  {:else}
  <div class="wrap">
    <table>
      <thead><tr><th>Time</th><th>Type</th><th>Hook</th><th>Tool</th><th>Reason</th></tr></thead>
      <tbody>
        {#each data as r}
        <tr>
          <td class="time">{fmt(r.ts)}</td>
          <td><span class="badge badge-{r.event}">{r.event}</span></td>
          <td class="mono">{r.hook}</td>
          <td class="mono">{r.tool}</td>
          <td class="reason">{r.result || '—'}</td>
        </tr>
        {/each}
      </tbody>
    </table>
  </div>
  {/if}
</div>
<style>
  .wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead tr { background: var(--color-near-black); }
  th { color: #fff; font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; padding: 12px 16px; text-align: left; white-space: nowrap; }
  td { padding: 11px 16px; border-bottom: 1px solid var(--color-light-gray); color: var(--color-near-black); vertical-align: middle; }
  tbody tr:hover td { background: var(--color-off-white); }
  tbody tr:last-child td { border-bottom: none; }
  .time { font-size: 12px; color: var(--color-meta-gray); white-space: nowrap; }
  .mono { font-family: 'SF Mono', Consolas, monospace; font-size: 12px; }
  .reason { max-width: 320px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--color-meta-gray); font-size: 12px; }
  .empty { font-size: 13px; color: var(--color-meta-gray); padding: var(--space-3) 0; }
</style>
