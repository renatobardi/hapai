<script>
  import { t } from '../stores/i18n.js'
  import { onMount } from 'svelte'

  let { label = '', value = 0, accent = 'default', sparklineData = [], trend = null } = $props()

  let canvas = $state()

  function drawSparkline() {
    if (!canvas || sparklineData.length < 2) return
    const ctx = canvas.getContext('2d')
    const w = canvas.width
    const h = canvas.height
    ctx.clearRect(0, 0, w, h)
    const s = getComputedStyle(document.documentElement)
    const color = accent === 'deny' ? s.getPropertyValue('--color-deny').trim()
                : accent === 'warn' ? s.getPropertyValue('--color-warn').trim()
                : s.getPropertyValue('--color-blue').trim()
    const min = Math.min(...sparklineData)
    const max = Math.max(...sparklineData)
    const range = max - min || 1
    ctx.strokeStyle = color
    ctx.lineWidth = 1.5
    ctx.beginPath()
    sparklineData.forEach((v, i) => {
      const x = (i / (sparklineData.length - 1)) * w
      const y = h - 2 - ((v - min) / range) * (h - 4)
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
    })
    ctx.stroke()
  }

  $effect(() => {
    if (canvas && sparklineData.length >= 2) drawSparkline()
  })

  onMount(drawSparkline)

  let trendDir = $derived(trend === null ? null : trend > 5 ? 'up' : trend < -5 ? 'down' : 'flat')
  let trendAbs = $derived(trend === null ? '' : (trend > 0 ? '+' : '') + Math.round(trend) + '%')
</script>

<div class="card" class:deny={accent==='deny'} class:warn={accent==='warn'}>
  <div class="label">{label}</div>
  <div class="value-row">
    <div class="value" class:vdeny={accent==='deny'} class:vwarn={accent==='warn'}>{value}</div>
    {#if trendDir !== null}
      <div class="trend" class:up={trendDir==='up'} class:down={trendDir==='down'} class:flat={trendDir==='flat'}>
        {trendDir === 'up' ? '↗' : trendDir === 'down' ? '↘' : '→'} {trendAbs}
      </div>
    {/if}
  </div>
  {#if sparklineData.length > 1}
    <canvas bind:this={canvas} width={80} height={24} class="sparkline"></canvas>
  {/if}
  <div class="period">{$t('statCard.period')}</div>
</div>

<style>
  .card { background: var(--color-white); border: 1px solid var(--color-light-gray); border-top: 3px solid var(--color-light-gray); padding: var(--space-3); display: flex; flex-direction: column; gap: var(--space-1); }
  .deny { border-top-color: var(--color-deny); }
  .warn { border-top-color: var(--color-warn); }
  .label { font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--color-meta-gray); }
  .value-row { display: flex; align-items: baseline; gap: 8px; }
  .value { font-size: 56px; font-weight: var(--weight-light); color: var(--color-near-black); line-height: 1; }
  .vdeny { color: var(--color-deny); }
  .vwarn { color: var(--color-warn); }
  .trend { font-size: 11px; font-weight: var(--weight-bold); letter-spacing: 0.04em; white-space: nowrap; }
  .trend.up   { color: var(--color-trend-up); }
  .trend.down { color: var(--color-trend-down); }
  .trend.flat { color: var(--color-trend-flat); }
  .sparkline { display: block; }
  .period { font-size: 11px; color: var(--color-meta-gray); }
</style>
