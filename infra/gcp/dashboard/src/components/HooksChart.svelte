<script>
  import { onMount, onDestroy } from 'svelte'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  import Card from './Card.svelte'
  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

  let { data = [] } = $props()

  let canvas = $state()
  let chart

  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim() }
  function hex2rgba(hex, a) {
    const r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16)
    return `rgba(${r},${g},${b},${a})`
  }

  function build() {
    if (!canvas || !data.length) return
    const cDeny  = css('--color-deny')
    const cGray  = css('--color-meta-gray')
    const cBlack = css('--color-near-black')
    const cLight = css('--color-light-gray')
    if (chart) chart.destroy()
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map(d => d.hook),
        datasets: [{ data: data.map(d => d.blocks), backgroundColor: hex2rgba(cDeny, 0.85), borderRadius: 0, borderWidth: 0 }]
      },
      options: {
        indexAxis: 'y', responsive: true, maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: cGray, font: { size: 11 } }, grid: { color: cLight }, border: { color: cLight } },
          y: { ticks: { color: cBlack, font: { size: 12, weight: '700' } }, grid: { display: false }, border: { display: false } }
        }
      }
    })
  }

  $effect(() => { if (canvas && data.length) { $locale; build() } })
  onMount(build)
  onDestroy(() => chart?.destroy())
</script>
<Card title={$t('charts.hooks')}><div class="w"><canvas bind:this={canvas}></canvas></div></Card>
<style>.w { height: 260px; position: relative; }</style>
