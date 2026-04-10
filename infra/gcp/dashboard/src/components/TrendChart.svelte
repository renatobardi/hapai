<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  Chart.register(LineController, LineElement, PointElement, CategoryScale, LinearScale, Filler, Tooltip, Legend)
  export let data = []
  let canvas; let chart
  function build() {
    if (!canvas || !data.length) return
    const T = get(t)
    const s = getComputedStyle(document.documentElement)
    const cDeny        = s.getPropertyValue('--color-deny').trim()
    const cWhite       = s.getPropertyValue('--color-white').trim()
    const cMetaGray    = s.getPropertyValue('--color-meta-gray').trim()
    const cGrid        = s.getPropertyValue('--color-grid-on-dark').trim()
    const cBorderDark  = s.getPropertyValue('--color-border-on-dark').trim()
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'line', data:{ labels:data.map(d=>d.day), datasets:[{label:T('charts.labels.denialsPerDay'),data:data.map(d=>d.denies),borderColor:cDeny,backgroundColor:'rgba(192,57,43,0.08)',borderWidth:2,pointRadius:3,pointBackgroundColor:cDeny,tension:0,fill:true}] },
      options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{labels:{color:cWhite,font:{weight:'700',size:12},boxWidth:12}}},
        scales:{x:{ticks:{color:cMetaGray,font:{size:11}},grid:{color:cGrid},border:{color:cBorderDark}},y:{ticks:{color:cMetaGray,font:{size:11}},grid:{color:cGrid},border:{color:cBorderDark}}}} })
  }
  $: if (canvas && data && $locale) build()
  onMount(build); onDestroy(()=>chart?.destroy())
</script>
<div class="dark"><div class="inner"><div class="card-title">{$t('charts.trend')}</div><div class="w"><canvas bind:this={canvas}></canvas></div></div></div>
<style>
  .dark { background: var(--color-near-black); padding: var(--space-3); margin-top: var(--space-3); }
  .inner { max-width: 1400px; margin: 0 auto; }
  .card-title { font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--color-meta-gray); margin-bottom: var(--space-2); }
  .w { height: 180px; position: relative; }
</style>
