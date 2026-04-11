<script>
  import { onMount } from 'svelte'
  import { authStore } from '../stores/auth.js'
  import { dashboardStore, loadDashboard } from '../stores/dashboard.js'
  import { t } from '../stores/i18n.js'
  import StatCard from './StatCard.svelte'
  import TimelineChart from './TimelineChart.svelte'
  import HooksChart from './HooksChart.svelte'
  import DenialsTable from './DenialsTable.svelte'
  import Hotspots from './Hotspots.svelte'
  import DrillDown from './DrillDown.svelte'
  import EventDetail from './EventDetail.svelte'
  import LoadingState from './LoadingState.svelte'

  onMount(() => { if ($authStore.idToken) loadDashboard($authStore.idToken) })

  $effect(() => {
    if ($authStore.idToken && !$dashboardStore.stats && !$dashboardStore.loading) loadDashboard($authStore.idToken)
  })

  // Clear detail/drilldown when data reloads — object references change and become stale
  $effect(() => {
    if ($dashboardStore.loading) { activeEvent = null; drilldown = null }
  })

  const stats = (s) => (s && s[0]) ? s[0] : { denials: 0, warnings: 0 }

  function sparkline(timeline, eventType) {
    if (!timeline) return []
    const byDay = {}
    for (const r of timeline) {
      if (r.event === eventType) byDay[r.day] = (byDay[r.day] || 0) + r.count
    }
    return Object.entries(byDay).sort(([a],[b]) => a.localeCompare(b)).map(([,v]) => v)
  }

  function calcTrend(data) {
    if (!data || data.length < 4) return null
    const mid    = Math.floor(data.length / 2)
    const oldAvg = data.slice(0, mid).reduce((a,b) => a+b, 0) / mid
    const newAvg = data.slice(mid).reduce((a,b) => a+b, 0) / (data.length - mid)
    if (oldAvg === 0) return null
    return ((newAvg - oldAvg) / oldAvg) * 100
  }

  let denialSparkline  = $derived(sparkline($dashboardStore.timeline, 'deny'))
  let warningSparkline = $derived(sparkline($dashboardStore.timeline, 'warn'))
  let denialTrend      = $derived(calcTrend(denialSparkline))
  let warningTrend     = $derived(calcTrend(warningSparkline))

  // Drill-down state: { type: 'guard'|'tool'|'project', name: string } | null
  let drilldown   = $state(null)
  // Event detail state: event object | null
  let activeEvent = $state(null)

  function openGuard(name)             { drilldown = { type: 'guard', name } }
  function openHotspot({ type, name }) { drilldown = { type, name } }
  function closeDrilldown()            { drilldown = null }
  function openEvent(event)            { activeEvent = event }
  function closeEvent()                { activeEvent = null }
</script>

{#if $dashboardStore.loading}
  <div class="loading-wrap"><LoadingState message={$t('dashboard.loading')} /></div>
{:else if $dashboardStore.error}
  <div class="err-wrap">
    <div class="err">
      <span class="elabel">{$t('dashboard.error')}</span>
      <p>{$dashboardStore.error}</p>
      <button onclick={() => loadDashboard($authStore.idToken)}>{$t('dashboard.retry')}</button>
    </div>
  </div>
{:else}
  {@const s = stats($dashboardStore.stats)}
  <div class="dashboard">

    <!-- L1: KPI row + timeline -->
    <div class="section">
      <div class="content">
        <div class="row top">
          <StatCard
            label={$t('dashboard.denials')}
            value={s.denials  ?? 0}
            accent="deny"
            sparklineData={denialSparkline}
            trend={denialTrend}
          />
          <StatCard
            label={$t('dashboard.warnings')}
            value={s.warnings ?? 0}
            accent="warn"
            sparklineData={warningSparkline}
            trend={warningTrend}
          />
          <div class="timeline">
            {#if $dashboardStore.timeline}
              <TimelineChart data={$dashboardStore.timeline} />
            {/if}
          </div>
        </div>
      </div>
    </div>

    <!-- L1: Recent events feed -->
    <div class="section alt">
      <div class="content">
        {#if $dashboardStore.denials}
          <DenialsTable
            data={$dashboardStore.denials}
            onselect={openEvent}
          />
        {/if}
      </div>
    </div>

    <!-- L1: Charts + inline drill-down (L2) -->
    <div class="section">
      <div class="content">
        <div class="row charts">
          {#if $dashboardStore.hooks}
            <HooksChart
              data={$dashboardStore.hooks}
              onselect={openGuard}
            />
          {/if}
          <Hotspots
            tools={$dashboardStore.tools ?? []}
            projects={$dashboardStore.projects ?? []}
            onselect={openHotspot}
          />
        </div>

        <!-- L2: Drill-down panel — inline, below charts -->
        {#if drilldown}
          <DrillDown
            type={drilldown.type}
            name={drilldown.name}
            denials={$dashboardStore.denials ?? []}
            onclose={closeDrilldown}
            onselect={openEvent}
          />
        {/if}
      </div>
    </div>

  </div>

  <!-- L3: Event detail drawer -->
  {#if activeEvent}
    <EventDetail
      event={activeEvent}
      events={$dashboardStore.denials ?? []}
      onclose={closeEvent}
    />
  {/if}
{/if}

<style>
  .loading-wrap, .err-wrap { flex: 1; display: flex; align-items: flex-start; justify-content: center; padding: var(--space-4) var(--space-3); }
  .err { border: 1px solid var(--color-deny); border-left: 4px solid var(--color-deny); padding: var(--space-3); display: flex; align-items: center; gap: var(--space-2); max-width: 800px; width: 100%; }
  .elabel { font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: .08em; color: var(--color-deny); white-space: nowrap; }
  .err p { flex: 1; font-size: 13px; }
  .err button { background: var(--color-deny); color: #fff; padding: 8px 16px; font-size: 12px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: .05em; }

  .dashboard { flex: 1; display: flex; flex-direction: column; }
  .section { width: 100%; padding: var(--space-4) var(--space-3); }
  .section.alt { background: var(--color-off-white); }
  .content { max-width: 1400px; margin: 0 auto; width: 100%; display: flex; flex-direction: column; gap: var(--space-3); }

  .row { display: grid; gap: var(--space-3); }
  .top { grid-template-columns: 200px 200px 1fr; }
  .charts { grid-template-columns: 1fr 1fr; }
  .timeline { min-width: 0; }

  @media (max-width: 900px) {
    .top    { grid-template-columns: 1fr 1fr; }
    .timeline { grid-column: 1 / -1; }
    .charts { grid-template-columns: 1fr; }
  }
  @media (max-width: 480px) {
    .top { grid-template-columns: 1fr; }
  }
</style>
