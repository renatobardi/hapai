<script>
  import { t, locale } from '../stores/i18n.js'
  import Badge from './Badge.svelte'
  import Card from './Card.svelte'
  import EmptyState from './EmptyState.svelte'

  let { data = [], onselect = null } = $props()

  const LIMIT = 20
  let filterType = $state('all')
  let filterHook = $state('')
  let filterTool = $state('')
  let showAll    = $state(false)

  const fmtTime = ts => {
    const d = new Date(ts), now = new Date()
    const mins = Math.floor((now - d) / 60000)
    if (mins < 1)   return $t('common.justNow')
    if (mins < 60)  return mins + $t('common.minutesAgo')
    const hrs = Math.floor(mins / 60)
    if (hrs < 24)   return hrs + $t('common.hoursAgo')
    return d.toLocaleDateString($locale, { month: 'short', day: 'numeric' })
  }

  let allHooks = $derived([...new Set(data.map(r => r.hook))].filter(Boolean).sort())
  let allTools = $derived([...new Set(data.map(r => r.tool))].filter(Boolean).sort())

  let filtered = $derived(data.filter(r => {
    if (filterType !== 'all' && r.event !== filterType) return false
    if (filterHook && r.hook !== filterHook) return false
    if (filterTool && r.tool !== filterTool) return false
    return true
  }))

  let displayed  = $derived(showAll ? filtered : filtered.slice(0, LIMIT))
  let hasFilters = $derived(filterType !== 'all' || filterHook !== '' || filterTool !== '')

  // Reset pagination when filters change or data is replaced
  $effect(() => { filterType; filterHook; filterTool; showAll = false })
  $effect(() => { data; showAll = false })

  function clearFilters() { filterType = 'all'; filterHook = ''; filterTool = '' }
</script>

<Card title={$t('table.title')}>
  <div class="filters">
    <select bind:value={filterType}>
      <option value="all">{$t('table.filterAll')}</option>
      <option value="deny">Deny</option>
      <option value="warn">Warn</option>
    </select>
    {#if allHooks.length > 1}
      <select bind:value={filterHook}>
        <option value="">{$t('table.filterHook')}</option>
        {#each allHooks as h}<option value={h}>{h}</option>{/each}
      </select>
    {/if}
    {#if allTools.length > 1}
      <select bind:value={filterTool}>
        <option value="">{$t('table.filterTool')}</option>
        {#each allTools as tool}<option value={tool}>{tool}</option>{/each}
      </select>
    {/if}
    {#if hasFilters}
      <button class="clear" onclick={clearFilters}>{$t('table.clearFilters')}</button>
    {/if}
  </div>

  {#if !filtered.length}
    <EmptyState message={hasFilters ? $t('table.noMatches') : $t('table.empty')} />
  {:else}
    <div class="wrap">
      <table>
        <thead><tr>
          <th>{$t('table.cols.time')}</th>
          <th>{$t('table.cols.type')}</th>
          <th>{$t('table.cols.hook')}</th>
          <th>{$t('table.cols.tool')}</th>
          <th>{$t('table.cols.reason')}</th>
        </tr></thead>
        <tbody>
          {#each displayed as r}
          <tr onclick={() => onselect?.(r)} class:clickable={!!onselect}>
            <td class="time">{fmtTime(r.ts)}</td>
            <td><Badge type={r.event}>{r.event}</Badge></td>
            <td class="mono">{r.hook}</td>
            <td class="mono">{r.tool}</td>
            <td class="reason"><span class="preview">{r.result || '—'}</span></td>
          </tr>
          {/each}
        </tbody>
      </table>
    </div>
    {#if !showAll && filtered.length > LIMIT}
      <div class="viewall">
        <button onclick={() => showAll = true}>{$t('table.viewAll')} ({filtered.length}) →</button>
      </div>
    {/if}
  {/if}
</Card>

<style>
  .filters { display: flex; gap: var(--space-1); margin-bottom: var(--space-2); flex-wrap: wrap; align-items: center; }
  .filters select {
    background: var(--color-white); border: 1px solid var(--color-border-medium);
    padding: 4px 8px; font-size: 11px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-near-black);
    font-family: var(--font); cursor: pointer;
  }
  .clear {
    background: none; border: 1px solid var(--color-border-medium);
    padding: 4px 10px; font-size: 11px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-meta-gray);
    cursor: pointer; transition: color var(--transition-fast);
  }
  .clear:hover { color: var(--color-near-black); }
  .wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead tr { background: var(--color-near-black); }
  th { color: #fff; font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; padding: 12px 16px; text-align: left; white-space: nowrap; }
  td { padding: 11px 16px; border-bottom: 1px solid var(--color-light-gray); color: var(--color-near-black); vertical-align: middle; }
  tbody tr { transition: background var(--transition-fast); }
  tbody tr.clickable { cursor: pointer; }
  tbody tr.clickable:hover td { background: var(--color-off-white); }
  tbody tr:last-child td { border-bottom: none; }
  .time { font-size: 12px; color: var(--color-meta-gray); white-space: nowrap; }
  .mono { font-family: 'SF Mono', Consolas, monospace; font-size: 12px; }
  .reason { color: var(--color-meta-gray); font-size: 12px; }
  .preview { display: block; max-width: 320px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .viewall { text-align: center; padding: var(--space-2) 0 0; border-top: 1px solid var(--color-light-gray); }
  .viewall button {
    background: none; border: none; font-size: 12px; font-weight: var(--weight-bold);
    color: var(--color-blue); cursor: pointer; text-transform: uppercase; letter-spacing: 0.04em;
  }
  .viewall button:hover { text-decoration: underline; }
</style>
