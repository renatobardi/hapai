<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend)
  export let data = []
  let canvas; let chart
  function build() {
    if (!canvas || !data.length) return
    const T = get(t)
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'bar', data:{ labels:data.map(d=>d.project.split('/').pop()), datasets:[{label:T('charts.labels.denials'),data:data.map(d=>d.count),backgroundColor:'rgba(39,174,96,0.85)',borderRadius:0,borderWidth:0}] },
      options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:'#757575',font:{size:11},maxRotation:30},grid:{display:false},border:{display:false}},y:{ticks:{color:'#757575',font:{size:11}},grid:{color:'#f0f0f0'},border:{color:'#f0f0f0'}}}} })
  }
  $: if (canvas && data && $locale) build()
  onMount(build); onDestroy(()=>chart?.destroy())
</script>
<div class="card"><div class="card-title">{$t('charts.projects')}</div><div class="w"><canvas bind:this={canvas}></canvas></div></div>
<style>.w{height:260px;position:relative;}</style>
