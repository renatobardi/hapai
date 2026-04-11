<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  import Card from './Card.svelte'
  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

  let { tools = [], projects = [] } = $props()

  let activeTab = $state('tool')
  let canvas = $state()
  let chart

  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim() }
  function hex2rgba(hex, a) {
    const r = parseInt(hex.slice(1,3), 16), g = parseInt(hex.slice(3,5), 16), b = parseInt(hex.slice(5,7), 16)
    return `rgba(${r},${g},${b},${a})`
  }

  function build() {
    if (!canvas) return
    if (chart) chart.destroy()
    const data = activeTab === 'tool' ? tools : projects
    if (!data.length) return
    const cBlue  = css('--color-blue')
    const cAllow = css('--color-allow')
    const cGray  = css('--color-meta-gray')
    const cBlack = css('--color-near-black')
    const cLight = css('--color-light-gray')
    const bgColor = activeTab === 'tool' ? hex2rgba(cBlue, 0.85) : hex2rgba(cAllow, 0.85)
    const labels  = activeTab === 'tool'
      ? data.map(d => d.tool)
      : data.map(d => d.project.split('/').pop())
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [{ data: data.map(d => d.count), backgroundColor: bgColor, borderRadius: 0, borderWidth: 0 }]
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

  $effect(() => { if (canvas) { $locale; build() } })
  $effect(() => { activeTab; if (canvas) build() })
  onMount(build)
  onDestroy(() => chart?.destroy())
</script>

<Card title={$t('charts.hotspots.title')}>
  <div class="tabs">
    <button class:active={activeTab==='tool'}    onclick={() => activeTab='tool'}>{$t('charts.hotspots.byTool')}</button>
    <button class:active={activeTab==='project'} onclick={() => activeTab='project'}>{$t('charts.hotspots.byProject')}</button>
  </div>
  <div class="w"><canvas bind:this={canvas}></canvas></div>
</Card>

<style>
  .tabs { display: flex; gap: 0; margin-bottom: var(--space-2); border-bottom: 1px solid var(--color-light-gray); }
  .tabs button {
    background: none; border: none; padding: 6px 14px;
    font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase;
    letter-spacing: 0.06em; color: var(--color-meta-gray);
    cursor: pointer; transition: color var(--transition-fast);
    border-bottom: 2px solid transparent; margin-bottom: -1px;
  }
  .tabs button:hover { color: var(--color-near-black); }
  .tabs button.active { color: var(--color-near-black); border-bottom-color: var(--color-near-black); }
  .w { height: 260px; position: relative; }
</style>
