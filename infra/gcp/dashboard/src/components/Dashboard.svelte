<script>
  import { onMount } from 'svelte'
  import { authStore } from '../stores/auth.js'
  import { dashboardStore, loadDashboard } from '../stores/dashboard.js'
  import { t } from '../stores/i18n.js'
  import StatCard from './StatCard.svelte'
  import TimelineChart from './TimelineChart.svelte'
  import HooksChart from './HooksChart.svelte'
  import DenialsTable from './DenialsTable.svelte'
  import ToolsChart from './ToolsChart.svelte'
  import ProjectsChart from './ProjectsChart.svelte'
  import TrendChart from './TrendChart.svelte'
  import LoadingState from './LoadingState.svelte'

  onMount(() => { if ($authStore.idToken) loadDashboard($authStore.idToken) })
  $: if ($authStore.idToken && !$dashboardStore.stats && !$dashboardStore.loading) loadDashboard($authStore.idToken)

  const stats = (s) => (s && s[0]) ? s[0] : { denials: 0, warnings: 0 }
</script>

{#if $dashboardStore.loading}
  <div class="content"><LoadingState message={$t('dashboard.loading')} /></div>
{:else if $dashboardStore.error}
  <div class="content">
    <div class="err">
      <span class="elabel">{$t('dashboard.error')}</span>
      <p>{$dashboardStore.error}</p>
      <button on:click={() => loadDashboard($authStore.idToken)}>{$t('dashboard.retry')}</button>
    </div>
  </div>
{:else}
  {@const s = stats($dashboardStore.stats)}
  <div class="content">
    <div class="row top">
      <StatCard label={$t('dashboard.denials')}  value={s.denials  ?? 0} accent="deny" />
      <StatCard label={$t('dashboard.warnings')} value={s.warnings ?? 0} accent="warn" />
      <div class="timeline">{#if $dashboardStore.timeline}<TimelineChart data={$dashboardStore.timeline} />{/if}</div>
    </div>
    {#if $dashboardStore.denials}<DenialsTable data={$dashboardStore.denials} />{/if}
    <div class="row charts">
      {#if $dashboardStore.hooks}<HooksChart data={$dashboardStore.hooks} />{/if}
      {#if $dashboardStore.tools}<ToolsChart data={$dashboardStore.tools} />{/if}
      {#if $dashboardStore.projects}<ProjectsChart data={$dashboardStore.projects} />{/if}
    </div>
    {#if $dashboardStore.trends}<TrendChart data={$dashboardStore.trends} />{/if}
  </div>
{/if}

<style>
  .content { flex:1; max-width:1400px; margin:0 auto; width:100%; padding:var(--space-4) var(--space-3) 0; display:flex; flex-direction:column; gap:var(--space-3); }
  .row { display:grid; gap:var(--space-3); }
  .top { grid-template-columns: 200px 200px 1fr; }
  .charts { grid-template-columns: repeat(3,1fr); }
  .timeline { min-width:0; }
  .err { border:1px solid var(--color-deny); border-left:4px solid var(--color-deny); padding:var(--space-3); display:flex; align-items:center; gap:var(--space-2); }
  .elabel { font-size:11px; font-weight:var(--weight-bold); text-transform:uppercase; letter-spacing:.08em; color:var(--color-deny); white-space:nowrap; }
  .err p { flex:1; font-size:13px; }
  .err button { background:var(--color-deny); color:#fff; padding:8px 16px; font-size:12px; font-weight:var(--weight-bold); text-transform:uppercase; letter-spacing:.05em; }
  @media(max-width:900px){.top{grid-template-columns:1fr 1fr;}.timeline{grid-column:1/-1;}.charts{grid-template-columns:1fr;}}
  @media(max-width:480px){.top{grid-template-columns:1fr;}}
</style>
