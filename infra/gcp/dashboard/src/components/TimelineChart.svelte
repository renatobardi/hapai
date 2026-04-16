<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  Chart.register(LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend)

  let { data = [], period = 7, onperiod = null } = $props()

  let canvas = $state()
  let chart

  // Show rate (%) instead of raw counts — avoids "is 100 denials high or low?" problem
  let mode = $state('rate')  // 'rate' | 'count'

  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim() }
  function hex2rgba(hex, a) {
    const r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16)
    return `rgba(${r},${g},${b},${a})`
  }

  function build() {
    if (!canvas || !data.length) return
    const cDeny  = css('--color-deny') || '#ef4444'
    const cWarn  = css('--color-warn') || '#f59e0b'
    const cGray  = css('--color-meta-gray') || '#888'
    const cLight = css('--color-light-gray') || '#f0f0f0'
    const cBlack = css('--color-near-black') || '#111'

    const byDay = {}
    for (const r of data) {
      if (!byDay[r.day]) byDay[r.day] = { denies: 0, warns: 0, allows: 0 }
      if (r.event === 'deny')  byDay[r.day].denies = r.count
      if (r.event === 'warn')  byDay[r.day].warns  = r.count
      if (r.event === 'allow') byDay[r.day].allows  = r.count
    }

    const days = Object.entries(byDay).sort(([a],[b]) => a.localeCompare(b))

    const denyData = days.map(([,v]) => {
      if (mode === 'rate') {
        const total = v.denies + v.warns + v.allows
        return total > 0 ? +((v.denies / total) * 100).toFixed(1) : 0
      }
      return v.denies
    })

    const warnData = days.map(([,v]) => {
      if (mode === 'rate') {
        const total = v.denies + v.warns + v.allows
        return total > 0 ? +((v.warns / total) * 100).toFixed(1) : 0
      }
      return v.warns
    })

    if (chart) chart.destroy()
    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: days.map(([d]) => d),
        datasets: [
          {
            label: mode === 'rate' ? 'Denial Rate (%)' : 'Denials',
            data: denyData,
            borderColor: cDeny,
            backgroundColor: hex2rgba(cDeny, 0.1),
            borderWidth: 2.5, pointRadius: 3, pointHoverRadius: 5, tension: 0.3, fill: 'origin'
          },
          {
            label: mode === 'rate' ? 'Warning Rate (%)' : 'Warnings',
            data: warnData,
            borderColor: cWarn,
            backgroundColor: hex2rgba(cWarn, 0.08),
            borderWidth: 2, pointRadius: 2, pointHoverRadius: 4, tension: 0.3, fill: 'origin'
          }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { labels: { color: cBlack, font: { weight: '700', size: 12 }, boxWidth: 12 } },
          tooltip: {
            callbacks: {
              label: ctx => mode === 'rate'
                ? `${ctx.dataset.label}: ${ctx.parsed.y}%`
                : `${ctx.dataset.label}: ${ctx.parsed.y.toLocaleString()}`
            }
          }
        },
        scales: {
          x: { ticks: { color: cGray, font: { size: 11 } }, grid: { color: cLight }, border: { color: cLight } },
          y: {
            ticks: {
              color: cGray, font: { size: 11 },
              callback: v => mode === 'rate' ? `${v}%` : v
            },
            grid: { color: cLight }, border: { color: cLight }, beginAtZero: true,
            ...(mode === 'rate' ? { max: 100 } : {})
          }
        }
      }
    })
  }

  $effect(() => { if (canvas && data.length) { $locale; build() } })
  $effect(() => { period; mode; if (canvas && data.length) build() })
  onMount(build)
  onDestroy(() => chart?.destroy())

  function changePeriod(p) { onperiod ? onperiod(p) : null }
  function toggleMode() { mode = mode === 'rate' ? 'count' : 'rate' }
</script>

<div class="card">
  <div class="header">
    <div>
      <div class="card-title">Activity Timeline</div>
      <div class="card-sub">Guardrail intervention rate over time</div>
    </div>
    <div class="controls">
      <button class="mode-btn" onclick={toggleMode} title="Toggle between rate and count">
        {mode === 'rate' ? '% Rate' : '# Count'}
      </button>
      <div class="periods">
        <button class:active={period===7}  onclick={() => changePeriod(7)}>7d</button>
        <button class:active={period===14} onclick={() => changePeriod(14)}>14d</button>
        <button class:active={period===30} onclick={() => changePeriod(30)}>30d</button>
      </div>
    </div>
  </div>
  <div class="w"><canvas bind:this={canvas}></canvas></div>
</div>

<style>
  .header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: var(--space-2); gap: 12px; }
  .card-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--color-text-muted, #666); }
  .card-sub { font-size: 12px; color: var(--color-meta-gray, #999); margin-top: 2px; }
  .w { height: 240px; position: relative; }
  .controls { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
  .periods { display: flex; gap: 2px; }
  .periods button {
    background: none; border: 1px solid var(--color-border-medium, #ddd);
    padding: 3px 10px; font-size: 11px; font-weight: 700;
    text-transform: uppercase; letter-spacing: .04em; color: var(--color-meta-gray, #888);
    cursor: pointer; transition: all .1s;
  }
  .periods button:hover { border-color: var(--color-near-black, #111); color: var(--color-near-black, #111); }
  .periods button.active { background: var(--color-near-black, #111); color: #fff; border-color: var(--color-near-black, #111); }
  .mode-btn {
    background: none; border: 1px solid var(--color-border-medium, #ddd);
    padding: 3px 10px; font-size: 11px; font-weight: 700;
    text-transform: uppercase; letter-spacing: .04em; color: var(--color-meta-gray, #888);
    cursor: pointer; transition: all .1s;
  }
  .mode-btn:hover { background: #f0f0f0; }
</style>
