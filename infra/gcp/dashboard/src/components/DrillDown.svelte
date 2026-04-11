<script>
  import { t, locale } from '../stores/i18n.js'
  import Badge from './Badge.svelte'
  import EmptyState from './EmptyState.svelte'

  let {
    type          = 'guard',   // 'guard' | 'tool' | 'project'
    name          = '',
    denials       = [],        // client-side fallback (all events from dashboardStore.denials)
    detail        = null,      // server-side detail from loadDrilldownDetail (or null)
    detailLoading = false,     // true while hook_detail / tool_detail is in flight
    onclose       = null,      // () => void
    onselect      = null       // (event) => void — open EventDetail
  } = $props()

  const fmtTime = ts => {
    const d = new Date(ts), now = new Date()
    const mins = Math.floor((now - d) / 60000)
    if (mins < 1)  return $t('common.justNow')
    if (mins < 60) return mins + $t('common.minutesAgo')
    const hrs = Math.floor(mins / 60)
    if (hrs < 24)  return hrs + $t('common.hoursAgo')
    return d.toLocaleDateString($locale, { month: 'short', day: 'numeric' })
  }

  // Client-side fallback: filter events to the selected entity
  let clientEvents = $derived(
    type === 'guard'   ? denials.filter(r => r.hook === name) :
    type === 'tool'    ? denials.filter(r => r.tool === name) :
    /* project */        denials.filter(r => r.project === name)
  )

  // Stats: prefer server-side detail, fall back to client-side counts
  let denyCount = $derived(detail ? (detail.deny_count ?? 0) : clientEvents.filter(r => r.event === 'deny').length)
  let warnCount = $derived(detail ? (detail.warn_count ?? 0) : clientEvents.filter(r => r.event === 'warn').length)
  let total     = $derived(detail ? (detail.total ?? 0)      : clientEvents.length)
  let denyRate  = $derived(total > 0 ? Math.round((denyCount / total) * 100) : 0)

  // Breakdown: prefer server-side detail, fall back to client-side computation
  let breakdownKey = $derived(type === 'guard' ? 'tool' : 'hook')

  let breakdown = $derived.by(() => {
    if (detail?.breakdown?.length) return detail.breakdown
    const counts = {}
    for (const e of clientEvents) {
      const k = e[breakdownKey] || '(unknown)'
      counts[k] = (counts[k] || 0) + 1
    }
    return Object.entries(counts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 6)
      .map(([label, count]) => ({ label, count }))
  })

  let maxCount = $derived(breakdown[0]?.count ?? 1)

  // Recent events: prefer server-side detail, fall back to client-side slice
  let recent = $derived(detail?.recent?.length ? detail.recent : clientEvents.slice(0, 8))

  // Mini-timeline from server-side detail (CSS bars, no Chart.js)
  let miniTimeline = $derived(detail?.timeline ?? [])
  let miniMax      = $derived(Math.max(...miniTimeline.map(d => d.count), 1))

  let breakdownLabel = $derived(
    type === 'guard' ? $t('drilldown.triggeredByTool') : $t('drilldown.triggeredByGuard')
  )

  let hasData = $derived(detail ? total > 0 : clientEvents.length > 0)
</script>

<div class="panel" role="region" aria-label="drill-down">
  <div class="panel-header">
    <div class="panel-title">
      <span class="mono">{name}</span>
      <span class="counts">
        {denyCount} {$t('drilldown.denials')}
        {#if warnCount > 0}· {warnCount} {$t('drilldown.warnings')}{/if}
        {#if total > 0}· {denyRate}% {$t('drilldown.denyRate')}{/if}
      </span>
    </div>
    <button class="close-btn" onclick={onclose} aria-label="close">{$t('drilldown.close')}</button>
  </div>

  <div class="panel-body">
    {#if detailLoading && !detail}
      <div class="detail-loading">{$t('drilldown.loading')}</div>
    {:else if !hasData}
      <EmptyState message={$t('drilldown.empty')} />
    {:else}
      <div class="two-col">

        <div class="left-col">
          <!-- Mini timeline (server-side, CSS bars) -->
          {#if miniTimeline.length > 1}
            <div class="section-label">{$t('drilldown.activity')}</div>
            <div class="mini-timeline">
              {#each miniTimeline as day}
                <div
                  class="mini-bar"
                  style="height: {Math.max(3, Math.round((day.count / miniMax) * 40))}px"
                  title="{day.day}: {day.count}"
                ></div>
              {/each}
            </div>
          {/if}

          <!-- Breakdown bars -->
          {#if breakdown.length > 0}
            <div class="breakdown">
              <div class="section-label">{breakdownLabel}</div>
              <div class="bars">
                {#each breakdown as item}
                  <div class="bar-row">
                    <span class="bar-label mono">{item.label}</span>
                    <div class="bar-track">
                      <div class="bar-fill" style="width: {Math.round((item.count / maxCount) * 100)}%"></div>
                    </div>
                    <span class="bar-count">{item.count}</span>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>

        <div class="recent">
          <div class="section-label">{$t('drilldown.recentEvents')}</div>
          <div class="event-list">
            {#each recent as r}
              <button class="event-row" class:clickable={!!onselect} onclick={() => onselect?.(r)} type="button">
                <span class="time">{fmtTime(r.ts)}</span>
                <Badge type={r.event}>{r.event}</Badge>
                <span class="mono small">{r.tool ?? r.hook}</span>
                <span class="reason">{r.result || '—'}</span>
              </button>
            {/each}
          </div>
        </div>

      </div>
    {/if}
  </div>
</div>

<style>
  .panel {
    border: 1px solid var(--color-border-medium);
    border-left: 3px solid var(--color-blue);
    background: var(--color-white);
    box-shadow: var(--shadow-md);
    animation: slide-down 150ms ease;
  }

  @keyframes slide-down {
    from { opacity: 0; transform: translateY(-8px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  .panel-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--color-light-gray);
    background: var(--color-off-white);
  }

  .panel-title { display: flex; align-items: baseline; gap: var(--space-2); flex-wrap: wrap; }
  .panel-title .mono { font-size: 14px; font-weight: var(--weight-bold); color: var(--color-near-black); }
  .counts { font-size: 12px; color: var(--color-meta-gray); }

  .close-btn {
    background: none; border: 1px solid var(--color-border-medium);
    width: 28px; height: 28px; font-size: 16px; color: var(--color-meta-gray);
    cursor: pointer; display: flex; align-items: center; justify-content: center;
    transition: all var(--transition-fast); flex-shrink: 0;
  }
  .close-btn:hover { border-color: var(--color-near-black); color: var(--color-near-black); }

  .panel-body { padding: var(--space-3); }

  .detail-loading { font-size: 12px; color: var(--color-meta-gray); padding: var(--space-2) 0; }

  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-4); }
  @media (max-width: 700px) { .two-col { grid-template-columns: 1fr; } }

  .left-col { display: flex; flex-direction: column; gap: var(--space-3); }

  .section-label {
    font-size: 10px; font-weight: var(--weight-bold); text-transform: uppercase;
    letter-spacing: 0.1em; color: var(--color-meta-gray); margin-bottom: var(--space-1);
  }

  /* Mini timeline */
  .mini-timeline {
    display: flex; align-items: flex-end; gap: 2px; height: 44px;
    border-bottom: 1px solid var(--color-light-gray); padding-bottom: 2px;
  }
  .mini-bar {
    flex: 1; background: var(--color-blue); opacity: 0.7; min-width: 3px;
    transition: opacity var(--transition-fast);
  }
  .mini-bar:hover { opacity: 1; }

  /* Breakdown bars */
  .bars { display: flex; flex-direction: column; gap: 10px; }
  .bar-row { display: grid; grid-template-columns: 120px 1fr 36px; align-items: center; gap: 10px; }
  .bar-label { font-size: 12px; color: var(--color-near-black); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bar-track { height: 8px; background: var(--color-light-gray); position: relative; }
  .bar-fill  { height: 100%; background: var(--color-blue); transition: width var(--transition-normal); }
  .bar-count { font-size: 12px; font-weight: var(--weight-bold); color: var(--color-meta-gray); text-align: right; }

  /* Recent events */
  .event-list { display: flex; flex-direction: column; gap: 1px; }
  .event-row {
    display: grid; grid-template-columns: 64px 48px 1fr 2fr;
    align-items: center; gap: 10px;
    padding: 8px 0; width: 100%;
    border: none; border-bottom: 1px solid var(--color-light-gray);
    background: none; text-align: left; font-family: var(--font);
    transition: background var(--transition-fast);
  }
  .event-row:last-child { border-bottom: none; }
  .event-row.clickable { cursor: pointer; padding: 8px 6px; margin: 0 -6px; }
  .event-row.clickable:hover { background: var(--color-off-white); }
  .time   { font-size: 11px; color: var(--color-meta-gray); white-space: nowrap; }
  .small  { font-size: 11px; }
  .reason { font-size: 11px; color: var(--color-meta-gray); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
</style>
