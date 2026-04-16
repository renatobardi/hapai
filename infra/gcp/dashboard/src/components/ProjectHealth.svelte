<script>
  const { data = [], onselect = () => {} } = $props()

  function healthGrade(denialRate) {
    if (denialRate === null || denialRate === undefined) return { grade: '?', color: '#999', label: 'No data' }
    if (denialRate <= 5)  return { grade: 'A', color: '#22c55e', label: 'Healthy' }
    if (denialRate <= 15) return { grade: 'B', color: '#84cc16', label: 'Good' }
    if (denialRate <= 30) return { grade: 'C', color: '#f59e0b', label: 'Attention' }
    if (denialRate <= 50) return { grade: 'D', color: '#f97316', label: 'At Risk' }
    return { grade: 'F', color: '#ef4444', label: 'Critical' }
  }

  function shortName(project) {
    if (!project) return 'unknown'
    // Show just the last path segment (repo name)
    return project.replace(/\/$/, '').split('/').pop() || project
  }

  function fmt(n) { return n == null ? '–' : n.toLocaleString() }
  function fmtPct(n) { return n == null ? '–' : `${n.toFixed(1)}%` }
</script>

<div class="ph-wrap">
  <div class="ph-header">
    <h2 class="ph-title">Project Health</h2>
    <p class="ph-subtitle">Guardrail denial rate per repository — lower is healthier</p>
  </div>

  {#if !data.length}
    <div class="ph-empty">No project data yet. Trigger some guardrails to see health scores.</div>
  {:else}
    <div class="ph-grid">
      {#each data as p}
        {@const h = healthGrade(p.denial_rate)}
        <button class="ph-card" onclick={() => onselect(p)} aria-label="View {shortName(p.project)} details">
          <div class="ph-grade" style="color: {h.color}; border-color: {h.color}">{h.grade}</div>
          <div class="ph-info">
            <div class="ph-name" title={p.project}>{shortName(p.project)}</div>
            <div class="ph-label" style="color: {h.color}">{h.label}</div>
            <div class="ph-stats">
              <span class="ph-stat deny">{fmt(p.denials)} denied</span>
              <span class="ph-sep">·</span>
              <span class="ph-stat warn">{fmt(p.warnings)} warned</span>
              <span class="ph-sep">·</span>
              <span class="ph-stat total">{fmt(p.total_events)} total</span>
            </div>
          </div>
          <div class="ph-rate" style="color: {h.color}">
            <div class="ph-rate-num">{fmtPct(p.denial_rate)}</div>
            <div class="ph-rate-label">denial rate</div>
          </div>
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .ph-wrap { display: flex; flex-direction: column; gap: 16px; }
  .ph-header { display: flex; flex-direction: column; gap: 4px; }
  .ph-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--color-text-muted, #666); margin: 0; }
  .ph-subtitle { font-size: 13px; color: var(--color-text-muted, #888); margin: 0; }
  .ph-empty { padding: 32px 0; text-align: center; color: var(--color-text-muted, #888); font-size: 14px; }

  .ph-grid { display: flex; flex-direction: column; gap: 8px; }

  .ph-card {
    display: flex; align-items: center; gap: 16px;
    padding: 16px; border: 1px solid var(--color-border, #e5e7eb);
    background: #fff; cursor: pointer; text-align: left; width: 100%;
    transition: border-color .15s, box-shadow .15s;
  }
  .ph-card:hover { border-color: var(--color-text-muted, #999); box-shadow: 0 2px 8px rgba(0,0,0,.06); }

  .ph-grade {
    width: 48px; height: 48px; border: 3px solid;
    display: flex; align-items: center; justify-content: center;
    font-size: 22px; font-weight: 800; flex-shrink: 0;
    border-radius: 2px;
  }

  .ph-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
  .ph-name { font-size: 15px; font-weight: 600; color: var(--color-text, #111); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ph-label { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; }
  .ph-stats { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
  .ph-stat { font-size: 12px; color: var(--color-text-muted, #666); }
  .ph-stat.deny { color: var(--color-deny, #ef4444); }
  .ph-stat.warn { color: var(--color-warn, #f59e0b); }
  .ph-sep { color: #ccc; font-size: 11px; }

  .ph-rate { text-align: right; flex-shrink: 0; }
  .ph-rate-num { font-size: 24px; font-weight: 800; line-height: 1; }
  .ph-rate-label { font-size: 11px; color: var(--color-text-muted, #888); text-transform: uppercase; letter-spacing: .05em; margin-top: 2px; }
</style>
