<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  Chart.register(LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend)

  let { data = [] } = $props()

  let canvas = $state()
  let period = $state(30)
  let chart

  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim() }
  function hex2rgba(hex, a) {
    const r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16)
    return `rgba(${r},${g},${b},${a})`
  }

  function build() {
    if (!canvas || !data.length) return
    const T = get(t)
    const cDeny  = css('--color-deny')
    const cWarn  = css('--color-warn')
    const cGray  = css('--color-meta-gray')
    const cLight = css('--color-light-gray')
    const cBlack = css('--color-near-black')

    const byDay = {}
    for (const r of data) {
      if (!byDay[r.day]) byDay[r.day] = { denies: 0, warns: 0 }
      if (r.event === 'deny') byDay[r.day].denies = r.count
      if (r.event === 'warn') byDay[r.day].warns  = r.count
    }
    const all  = Object.entries(byDay).sort(([a],[b]) => a.localeCompare(b))
    const days = period < 30 ? all.slice(-period) : all

    if (chart) chart.destroy()
    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: days.map(([d]) => d),
        datasets: [
          {
            label: T('charts.labels.denials'),
            data: days.map(([,v]) => v.denies),
            borderColor: cDeny,
            backgroundColor: hex2rgba(cDeny, 0.12),
            borderWidth: 2, pointRadius: 2, pointHoverRadius: 4, tension: 0.3, fill: 'origin'
          },
          {
            label: T('charts.labels.warnings'),
            data: days.map(([,v]) => v.warns),
            borderColor: cWarn,
            backgroundColor: hex2rgba(cWarn, 0.08),
            borderWidth: 2, pointRadius: 2, pointHoverRadius: 4, tension: 0.3, fill: 'origin'
          }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { labels: { color: cBlack, font: { weight: '700', size: 12 }, boxWidth: 12 } } },
        scales: {
          x: { ticks: { color: cGray, font: { size: 11 } }, grid: { color: cLight }, border: { color: cLight } },
          y: { ticks: { color: cGray, font: { size: 11 } }, grid: { color: cLight }, border: { color: cLight }, beginAtZero: true }
        }
      }
    })
  }

  $effect(() => { if (canvas && data.length) { $locale; build() } })
  $effect(() => { period; if (canvas && data.length) build() })
  onMount(build)
  onDestroy(() => chart?.destroy())
</script>

<div class="card">
  <div class="header">
    <div class="card-title">{$t('charts.timeline')}</div>
    <div class="periods">
      <button class:active={period===7}  onclick={() => period=7}>7d</button>
      <button class:active={period===14} onclick={() => period=14}>14d</button>
      <button class:active={period===30} onclick={() => period=30}>30d</button>
    </div>
  </div>
  <div class="w"><canvas bind:this={canvas}></canvas></div>
</div>

<style>
  .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--space-2); }
  .w { height: 220px; position: relative; }
  .periods { display: flex; gap: 2px; }
  .periods button {
    background: none; border: 1px solid var(--color-border-medium);
    padding: 3px 10px; font-size: 11px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-meta-gray);
    cursor: pointer; transition: all var(--transition-fast);
  }
  .periods button:hover { border-color: var(--color-near-black); color: var(--color-near-black); }
  .periods button.active { background: var(--color-near-black); color: var(--color-white); border-color: var(--color-near-black); }
</style>
