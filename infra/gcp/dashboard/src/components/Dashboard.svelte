<script>
  import { onMount } from 'svelte'
  import { authStore } from '../stores/auth.js'
  import { dashboardStore, loadDashboard } from '../stores/dashboard.js'
  import StatCard from './StatCard.svelte'
  import TimelineChart from './TimelineChart.svelte'
  import HooksChart from './HooksChart.svelte'
  import DenialsTable from './DenialsTable.svelte'
  import ToolsChart from './ToolsChart.svelte'
  import ProjectsChart from './ProjectsChart.svelte'
  import TrendChart from './TrendChart.svelte'
  import LoadingState from './LoadingState.svelte'

  onMount(() => {
    if ($authStore.idToken) {
      loadDashboard($authStore.idToken)
    }
  })

  $: if ($authStore.idToken && !$dashboardStore.stats && !$dashboardStore.loading) {
    loadDashboard($authStore.idToken)
  }

  function getStats(stats) {
    if (!stats || !stats[0]) return { denials: 0, warnings: 0 }
    return stats[0]
  }
</script>

{#if $dashboardStore.loading}
  <div class="content">
    <LoadingState message="Fetching analytics…" />
  </div>
{:else if $dashboardStore.error}
  <div class="content">
    <div class="error-banner">
      <span class="error-label">Error</span>
      <p>{$dashboardStore.error}</p>
      <button on:click={() => loadDashboard($authStore.idToken)}>Retry</button>
    </div>
  </div>
{:else}
  {@const s = getStats($dashboardStore.stats)}
  <div class="content">
    <!-- Row 1: stats + timeline -->
    <div class="row row-top">
      <StatCard label="Denials" value={s.denials ?? 0} accent="deny" />
      <StatCard label="Warnings" value={s.warnings ?? 0} accent="warn" />
      <div class="timeline-col">
        {#if $dashboardStore.timeline}
          <TimelineChart data={$dashboardStore.timeline} />
        {/if}
      </div>
    </div>

    <!-- Row 2: recent events table -->
    {#if $dashboardStore.denials}
      <DenialsTable data={$dashboardStore.denials} />
    {/if}

    <!-- Row 3: hooks + tools + projects -->
    <div class="row row-charts">
      {#if $dashboardStore.hooks}
        <HooksChart data={$dashboardStore.hooks} />
      {/if}
      {#if $dashboardStore.tools}
        <ToolsChart data={$dashboardStore.tools} />
      {/if}
      {#if $dashboardStore.projects}
        <ProjectsChart data={$dashboardStore.projects} />
      {/if}
    </div>
  </div>

  <!-- Row 4: trend — full width, dark section -->
  {#if $dashboardStore.trends}
    <TrendChart data={$dashboardStore.trends} />
  {/if}
{/if}

<style>
  .content {
    flex: 1;
    max-width: 1400px;
    margin: 0 auto;
    width: 100%;
    padding: var(--space-4) var(--space-3) 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .row {
    display: grid;
    gap: var(--space-3);
  }

  .row-top {
    grid-template-columns: 200px 200px 1fr;
  }

  .row-charts {
    grid-template-columns: repeat(3, 1fr);
  }

  .timeline-col {
    min-width: 0;
  }

  .error-banner {
    border: 1px solid var(--color-deny);
    border-left: 4px solid var(--color-deny);
    padding: var(--space-3);
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .error-label {
    font-size: 11px;
    font-weight: var(--weight-bold);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--color-deny);
    white-space: nowrap;
  }

  .error-banner p {
    flex: 1;
    font-size: 13px;
    color: var(--color-near-black);
  }

  .error-banner button {
    background: var(--color-deny);
    color: white;
    padding: 8px 16px;
    font-size: 12px;
    font-weight: var(--weight-bold);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border: none;
    border-radius: 0;
    cursor: pointer;
    white-space: nowrap;
  }

  @media (max-width: 900px) {
    .row-top {
      grid-template-columns: 1fr 1fr;
    }
    .timeline-col {
      grid-column: 1 / -1;
    }
    .row-charts {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 480px) {
    .row-top {
      grid-template-columns: 1fr;
    }
  }
</style>
