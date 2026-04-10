<script>
  import { onMount, onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend } from 'chart.js'
  import { t, locale } from '../stores/i18n.js'
  import Card from './Card.svelte'
  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend)
  export let data = []
  let canvas; let chart
  function build() {
    if (!canvas || !data.length) return
    const T = get(t)
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'bar', data:{ labels:data.map(d=>d.tool), datasets:[{label:T('charts.labels.denials'),data:data.map(d=>d.count),backgroundColor:'rgba(28,105,212,0.85)',borderRadius:0,borderWidth:0}] },
      options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false}},
        scales:{x:{ticks:{color:'#757575',font:{size:11}},grid:{color:'#f0f0f0'},border:{color:'#f0f0f0'}},y:{ticks:{color:'#262626',font:{size:12,weight:'700'}},grid:{display:false},border:{display:false}}}} })
  }
  $: if (canvas && data && $locale) build()
  onMount(build); onDestroy(()=>chart?.destroy())
</script>
<Card title={$t('charts.tools')}><div class="w"><canvas bind:this={canvas}></canvas></div></Card>
<style>.w{height:260px;position:relative;}</style>
