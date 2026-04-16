<script>
  // statsComparison: [{period_label: 'current'|'previous', total_events, denials, warnings, denial_rate, warning_rate}]
  const { statsComparison = null, period = 7 } = $props()

  let current  = $derived(statsComparison?.find(r => r.period_label === 'current')  ?? null)
  let previous = $derived(statsComparison?.find(r => r.period_label === 'previous') ?? null)

  function trendVsPrev(curr, prev) {
    if (curr == null || prev == null || prev === 0) return null
    return ((curr - prev) / prev) * 100
  }

  function trendLabel(pct) {
    if (pct == null) return ''
    const sign = pct > 0 ? '+' : ''
    return `${sign}${pct.toFixed(1)}% vs prev ${period}d`
  }

  function trendDir(pct, higherIsBad = true) {
    if (pct == null) return 'flat'
    const bad = higherIsBad ? pct > 5 : pct < -5
    const good = higherIsBad ? pct < -5 : pct > 5
    return bad ? 'up-bad' : good ? 'down-good' : 'flat'
  }

  let denialRateTrend  = $derived(trendVsPrev(current?.denial_rate,  previous?.denial_rate))
  let warningRateTrend = $derived(trendVsPrev(current?.warning_rate, previous?.warning_rate))
  let totalEventsTrend = $derived(trendVsPrev(current?.total_events,  previous?.total_events))
  let denialsTrend     = $derived(trendVsPrev(current?.denials,       previous?.denials))

  function fmt(n)    { return n == null ? '–' : n.toLocaleString() }
  function fmtPct(n) { return n == null ? '–' : `${(+n).toFixed(1)}%` }
</script>

<div class="kpi-bar">
  <!-- KPI 1: Total Actions Monitored -->
  <div class="kpi">
    <div class="kpi-label">Actions Monitored</div>
    <div class="kpi-value">{fmt(current?.total_events)}</div>
    <div class="kpi-trend {trendDir(totalEventsTrend, false)}">
      {trendLabel(totalEventsTrend) || `last ${period}d`}
    </div>
  </div>

  <div class="kpi-divider"></div>

  <!-- KPI 2: Denial Rate -->
  <div class="kpi">
    <div class="kpi-label">Denial Rate</div>
    <div class="kpi-value deny">{fmtPct(current?.denial_rate)}</div>
    <div class="kpi-trend {trendDir(denialRateTrend, true)}">
      {#if denialRateTrend != null}
        {trendLabel(denialRateTrend)}
      {:else}
        {fmt(current?.denials)} blocked
      {/if}
    </div>
  </div>

  <div class="kpi-divider"></div>

  <!-- KPI 3: Warning Rate -->
  <div class="kpi">
    <div class="kpi-label">Warning Rate</div>
    <div class="kpi-value warn">{fmtPct(current?.warning_rate)}</div>
    <div class="kpi-trend {trendDir(warningRateTrend, true)}">
      {#if warningRateTrend != null}
        {trendLabel(warningRateTrend)}
      {:else}
        {fmt(current?.warnings)} warned
      {/if}
    </div>
  </div>

  <div class="kpi-divider"></div>

  <!-- KPI 4: Total Denials (absolute) -->
  <div class="kpi">
    <div class="kpi-label">Total Blocked</div>
    <div class="kpi-value deny">{fmt(current?.denials)}</div>
    <div class="kpi-trend {trendDir(denialsTrend, true)}">
      {trendLabel(denialsTrend) || 'actions blocked by guardrails'}
    </div>
  </div>
</div>

<style>
  .kpi-bar {
    display: grid;
    grid-template-columns: 1fr auto 1fr auto 1fr auto 1fr;
    border: 1px solid var(--color-border, #e5e7eb);
    background: #fff;
  }

  .kpi {
    padding: 20px 24px;
    display: flex; flex-direction: column; gap: 6px;
  }

  .kpi-label {
    font-size: 11px; font-weight: 700; text-transform: uppercase;
    letter-spacing: .08em; color: var(--color-text-muted, #888);
  }

  .kpi-value {
    font-size: 32px; font-weight: 800; line-height: 1;
    color: var(--color-text, #111);
  }
  .kpi-value.deny { color: var(--color-deny, #ef4444); }
  .kpi-value.warn { color: var(--color-warn, #f59e0b); }

  .kpi-trend {
    font-size: 12px; color: var(--color-text-muted, #888); line-height: 1.3;
  }
  .kpi-trend.up-bad    { color: var(--color-deny, #ef4444); font-weight: 600; }
  .kpi-trend.up-bad::before   { content: '↑ '; }
  .kpi-trend.down-good { color: #22c55e; font-weight: 600; }
  .kpi-trend.down-good::before { content: '↓ '; }

  .kpi-divider { width: 1px; background: var(--color-border, #e5e7eb); margin: 16px 0; }

  @media (max-width: 900px) {
    .kpi-bar { grid-template-columns: 1fr 1fr; }
    .kpi-divider { display: none; }
    .kpi { border-bottom: 1px solid var(--color-border, #e5e7eb); }
  }
</style>
