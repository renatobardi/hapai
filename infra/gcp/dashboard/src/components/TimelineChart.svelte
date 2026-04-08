<script>
  import { onMount, onDestroy } from 'svelte'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend } from 'chart.js'

  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend)

  export let data = []

  let canvas
  let chart

  const CHART_DEFAULTS = {
    plugins: {
      legend: { labels: { color: '#262626', font: { weight: '700', size: 12 }, boxWidth: 12 } }
    },
    scales: {
      x: { ticks: { color: '#757575', font: { size: 11 } }, grid: { color: '#f0f0f0' }, border: { color: '#f0f0f0' } },
      y: { ticks: { color: '#757575', font: { size: 11 } }, grid: { color: '#f0f0f0' }, border: { color: '#f0f0f0' } },
    }
  }

  function buildChart() {
    if (!canvas || !data.length) return

    const byDay = {}
    for (const row of data) {
      if (!byDay[row.day]) byDay[row.day] = { denies: 0, warns: 0 }
      if (row.event === 'deny') byDay[row.day].denies = row.count
      if (row.event === 'warn') byDay[row.day].warns  = row.count
    }
    const sorted = Object.entries(byDay).sort(([a], [b]) => a.localeCompare(b))

    if (chart) chart.destroy()
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: sorted.map(([d]) => d),
        datasets: [
          { label: 'Denials', data: sorted.map(([, v]) => v.denies), backgroundColor: 'rgba(192,57,43,0.85)', borderRadius: 0, borderWidth: 0 },
          { label: 'Warnings', data: sorted.map(([, v]) => v.warns), backgroundColor: 'rgba(230,126,34,0.7)', borderRadius: 0, borderWidth: 0 },
        ],
      },
      options: { responsive: true, maintainAspectRatio: false, ...CHART_DEFAULTS },
    })
  }

  $: if (canvas && data) buildChart()

  onMount(buildChart)
  onDestroy(() => chart?.destroy())
</script>

<div class="card">
  <div class="card-title">Event Timeline — 30 days</div>
  <div class="chart-wrap">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>

<style>
  .chart-wrap {
    height: 220px;
    position: relative;
  }
</style>
