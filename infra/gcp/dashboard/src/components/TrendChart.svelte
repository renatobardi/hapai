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
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'line', data:{ labels:data.map(d=>d.day), datasets:[{label:T('charts.labels.denialsPerDay'),data:data.map(d=>d.denies),borderColor:'#c0392b',backgroundColor:'rgba(192,57,43,0.08)',borderWidth:2,pointRadius:3,pointBackgroundColor:'#c0392b',tension:0,fill:true}] },
      options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{labels:{color:'#ffffff',font:{weight:'700',size:12},boxWidth:12}}},
        scales:{x:{ticks:{color:'#757575',font:{size:11}},grid:{color:'rgba(255,255,255,0.08)'},border:{color:'rgba(255,255,255,0.1)'}},y:{ticks:{color:'#757575',font:{size:11}},grid:{color:'rgba(255,255,255,0.08)'},border:{color:'rgba(255,255,255,0.1)'}}}} })
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
