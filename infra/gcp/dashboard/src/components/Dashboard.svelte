<script>
  import { onMount } from 'svelte'
  import { authStore } from '../stores/auth.js'
  import { dashboardStore, loadDashboard, setPeriod, loadDrilldownDetail, loadMoreDenials } from '../stores/dashboard.js'
  import KpiBar from './KpiBar.svelte'
  import TimelineChart from './TimelineChart.svelte'
  import ProjectHealth from './ProjectHealth.svelte'
  import DenialReasons from './DenialReasons.svelte'
  import GuardrailGlossary from './GuardrailGlossary.svelte'
  import HooksChart from './HooksChart.svelte'
  import DenialsTable from './DenialsTable.svelte'
  import DrillDown from './DrillDown.svelte'
  import EventDetail from './EventDetail.svelte'
  import LoadingState from './LoadingState.svelte'

  // Load once on mount — use flag to prevent double-load from $effect
  let _loaded = false
  onMount(() => {
    if ($authStore.idToken && !_loaded) {
      _loaded = true
      loadDashboard($authStore.idToken, 7)
    }
  })

  // Fallback: if auth resolves after mount (e.g. page refresh), load then
  $effect(() => {
    if ($authStore.idToken && !_loaded && !$dashboardStore.loading) {
      _loaded = true
      loadDashboard($authStore.idToken, 7)
    }
    // Reset flag on logout so next login reloads
    if (!$authStore.idToken) _loaded = false
  })

  $effect(() => {
    if ($dashboardStore.loading) { activeEvent = null; drilldown = null }
  })

  // Active section tab
  let activeTab = $state('overview')  // 'overview' | 'projects' | 'guards' | 'events'

  // Drill-down state
  let drilldown   = $state(null)
  let activeEvent = $state(null)

  function openGuard(name) {
    drilldown = { type: 'guard', name }
    activeTab = 'guards'
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
  <div class="loading-wrap"><LoadingState message="Loading guardrail data…" /></div>

{:else if $dashboardStore.error}
  <div class="err-wrap">
    <div class="err">
      <span class="elabel">Error</span>
      <p>{$dashboardStore.error}</p>
      <button onclick={() => loadDashboard($authStore.idToken, $dashboardStore.period)}>Retry</button>
    </div>
  </div>

{:else}
  <div class="dashboard">

    <!-- Top KPI bar — always visible -->
    <div class="kpi-section">
      <div class="content">
        <KpiBar
          statsComparison={$dashboardStore.statsComparison}
          period={$dashboardStore.period}
        />
      </div>
    </div>

    <!-- Section tabs -->
    <div class="tabs-section">
      <div class="content">
        <nav class="tabs">
          <button class:active={activeTab==='overview'} onclick={() => activeTab='overview'}>Overview</button>
          <button class:active={activeTab==='projects'} onclick={() => activeTab='projects'}>Projects</button>
          <button class:active={activeTab==='guards'}   onclick={() => activeTab='guards'}>Guardrails</button>
          <button class:active={activeTab==='events'}   onclick={() => activeTab='events'}>Events</button>
        </nav>
      </div>
    </div>

    <!-- TAB: Overview -->
    {#if activeTab === 'overview'}
      <div class="section">
        <div class="content">
          <!-- Timeline — rate by default -->
          {#if $dashboardStore.timeline}
            <TimelineChart
              data={$dashboardStore.timeline}
              period={$dashboardStore.period}
              onperiod={onPeriodChange}
            />
          {/if}

          <!-- Two-column: top reasons + top guards -->
          <div class="two-col">
            <div class="col">
              <DenialReasons
                data={$dashboardStore.denialReasons ?? []}
                onselect={openGuard}
              />
            </div>
            <div class="col">
              {#if $dashboardStore.hooks}
                <HooksChart
                  data={$dashboardStore.hooks}
                  onselect={openGuard}
                />
              {/if}
            </div>
          </div>
        </div>
      </div>

    <!-- TAB: Projects -->
    {:else if activeTab === 'projects'}
      <div class="section">
        <div class="content">
          <ProjectHealth
            data={$dashboardStore.projectHealth ?? []}
            onselect={(p) => {
              drilldown = { type: 'project', name: p.project }
            }}
          />
        </div>
      </div>

    <!-- TAB: Guardrails -->
    {:else if activeTab === 'guards'}
      <div class="section">
        <div class="content">
          <GuardrailGlossary
            hooks={$dashboardStore.hooks ?? []}
            onselect={openGuard}
          />

          {#if drilldown && drilldown.type === 'guard'}
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

    <!-- TAB: Events -->
    {:else if activeTab === 'events'}
      <div class="section alt">
        <div class="content">
          {#if $dashboardStore.denials}
            <DenialsTable
              data={$dashboardStore.denials}
              onselect={openEvent}
              hasMore={$dashboardStore.denialsHasMore}
              onloadmore={() => loadMoreDenials($authStore.idToken, $dashboardStore.period)}
            />
          {/if}
        </div>
      </div>
    {/if}

  </div>

  <!-- Event detail drawer -->
  {#if activeEvent}
    <EventDetail
      event={activeEvent}
      events={$dashboardStore.denials ?? []}
      onclose={closeEvent}
    />
  {/if}
{/if}

<style>
  .loading-wrap, .err-wrap {
    flex: 1; display: flex; align-items: flex-start;
    justify-content: center; padding: var(--space-4) var(--space-3);
  }
  .err {
    border: 1px solid var(--color-deny, #ef4444);
    border-left: 4px solid var(--color-deny, #ef4444);
    padding: var(--space-3); display: flex; align-items: center;
    gap: var(--space-2); max-width: 800px; width: 100%;
  }
  .elabel {
    font-size: 11px; font-weight: 700; text-transform: uppercase;
    letter-spacing: .08em; color: var(--color-deny, #ef4444); white-space: nowrap;
  }
  .err p { flex: 1; font-size: 13px; }
  .err button {
    background: var(--color-deny, #ef4444); color: #fff;
    padding: 8px 16px; font-size: 12px; font-weight: 700;
    text-transform: uppercase; letter-spacing: .05em; border: none; cursor: pointer;
  }

  .dashboard { flex: 1; display: flex; flex-direction: column; }
  .content { max-width: 1400px; margin: 0 auto; width: 100%; display: flex; flex-direction: column; gap: var(--space-3); }

  .kpi-section { padding: 20px var(--space-3) 0; background: #fff; border-bottom: 1px solid var(--color-border, #e5e7eb); }

  .tabs-section { background: #fff; border-bottom: 2px solid var(--color-border, #e5e7eb); padding: 0 var(--space-3); }
  .tabs { display: flex; gap: 0; max-width: 1400px; margin: 0 auto; }
  .tabs button {
    background: none; border: none; border-bottom: 3px solid transparent;
    padding: 12px 20px; font-size: 13px; font-weight: 600;
    color: var(--color-text-muted, #888); cursor: pointer;
    transition: color .15s, border-color .15s;
    margin-bottom: -2px;
  }
  .tabs button:hover { color: var(--color-text, #111); }
  .tabs button.active { color: var(--color-text, #111); border-bottom-color: var(--color-text, #111); }

  .section { padding: var(--space-4) var(--space-3); }
  .section.alt { background: var(--color-off-white, #f9fafb); padding: var(--space-4) var(--space-3); }

  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-3); }
  .col { min-width: 0; }

  @media (max-width: 900px) {
    .two-col { grid-template-columns: 1fr; }
  }
</style>
