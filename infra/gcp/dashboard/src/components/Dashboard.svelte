<script>
  import { onMount } from 'svelte'
  import { authStore } from '../stores/auth.js'
  import { dashboardStore, loadDashboard, setPeriod, loadDrilldownDetail, loadMoreDenials } from '../stores/dashboard.js'
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

  const stats = (s) => (s && s[0]) ? s[0] : { denials: 0, warnings: 0, allow_count: 0, total_events: 0 }

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

  function dailyRates(timeline, eventType) {
    if (!timeline) return []
    const byDay = {}
    for (const r of timeline) {
      if (!byDay[r.day]) byDay[r.day] = { total: 0, count: 0 }
      byDay[r.day].total += r.count
      if (r.event === eventType) byDay[r.day].count = r.count
    }
    return Object.entries(byDay)
      .sort(([a],[b]) => a.localeCompare(b))
      .map(([, v]) => v.total > 0 ? (v.count / v.total) * 100 : 0)
  }

  let denialSparkline   = $derived(sparkline($dashboardStore.timeline, 'deny'))
  let warningSparkline  = $derived(sparkline($dashboardStore.timeline, 'warn'))
  let denialTrend       = $derived(calcTrend(denialSparkline))
  let warningTrend      = $derived(calcTrend(warningSparkline))
  let allowRateSpark    = $derived(dailyRates($dashboardStore.timeline, 'allow'))
  let denyRateSpark     = $derived(dailyRates($dashboardStore.timeline, 'deny'))
  let allowRateTrend    = $derived(calcTrend(allowRateSpark))
  let denyRateTrend     = $derived(calcTrend(denyRateSpark))

  // Drill-down state: { type: 'guard'|'tool'|'project', name: string } | null
  let drilldown   = $state(null)
  // Event detail state: event object | null
  let activeEvent = $state(null)

  function openGuard(name) {
    drilldown = { type: 'guard', name }
    loadDrilldownDetail('guard', name, $authStore.idToken, $dashboardStore.period)
  }
  function openHotspot({ type, name }) {
    drilldown = { type, name }
    if (type !== 'project') loadDrilldownDetail(type, name, $authStore.idToken, $dashboardStore.period)
  }
  function closeDrilldown()  { drilldown = null }
  function openEvent(event)  { activeEvent = event }
  function closeEvent()      { activeEvent = null }
  function onPeriodChange(p) { setPeriod($authStore.idToken, p) }
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
  {@const totalEvts  = s.total_events ?? 0}
  {@const allowRate  = totalEvts > 0 ? (s.allow_count ?? 0) / totalEvts * 100 : 0}
  {@const denyRate   = totalEvts > 0 ? (s.denials     ?? 0) / totalEvts * 100 : 0}
  <div class="dashboard">

    <!-- L1: KPI cards -->
    <div class="section">
      <div class="content">
        <div class="row kpis">
          <StatCard
            label={$t('dashboard.denials')}
            value={s.denials  ?? 0}
            accent="deny"
            sparklineData={denialSparkline}
            trend={denialTrend}
            period={$dashboardStore.period}
          />
          <StatCard
            label={$t('dashboard.warnings')}
            value={s.warnings ?? 0}
            accent="warn"
            sparklineData={warningSparkline}
            trend={warningTrend}
            period={$dashboardStore.period}
          />
          <StatCard
            label={$t('statCard.allowRate')}
            value={allowRate}
            accent="allow"
            format="percent"
            sparklineData={allowRateSpark}
            trend={allowRateTrend}
            period={$dashboardStore.period}
          />
          <StatCard
            label={$t('statCard.denyRate')}
            value={denyRate}
            accent="deny"
            format="percent"
            sparklineData={denyRateSpark}
            trend={denyRateTrend}
            period={$dashboardStore.period}
          />
        </div>

        <!-- Timeline spans full width below KPI row -->
        {#if $dashboardStore.timeline}
          <TimelineChart
            data={$dashboardStore.timeline}
            period={$dashboardStore.period}
            onperiod={onPeriodChange}
          />
        {/if}
      </div>
    </div>

    <!-- L1: Recent events feed -->
    <div class="section alt">
      <div class="content">
        {#if $dashboardStore.denials}
          <DenialsTable
            data={$dashboardStore.denials}
            onselect={openEvent}
            hasMore={$dashboardStore.denialsHasMore}
            onloadmore={() => loadMoreDenials($authStore.idToken)}
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
            detail={$dashboardStore.drilldownDetail}
            detailLoading={$dashboardStore.drilldownDetailLoading}
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
  .kpis   { grid-template-columns: repeat(4, 1fr); }
  .charts { grid-template-columns: 1fr 1fr; }

  @media (max-width: 900px) {
    .kpis   { grid-template-columns: 1fr 1fr; }
    .charts { grid-template-columns: 1fr; }
  }
  @media (max-width: 480px) {
    .kpis { grid-template-columns: 1fr 1fr; }
  }
</style>
