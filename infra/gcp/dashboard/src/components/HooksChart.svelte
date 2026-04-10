<script>
  import { onMount, onDestroy } from 'svelte'
  import { Chart, DoughnutController, ArcElement, Tooltip, Legend } from 'chart.js'
  import { t } from '../stores/i18n.js'
  import Card from './Card.svelte'
  Chart.register(DoughnutController, ArcElement, Tooltip, Legend)
  export let data = []
  let canvas; let chart
  const P = ['#1c69d4','#c0392b','#e67e22','#27ae60','#8e44ad','#2980b9','#16a085','#d35400']
  function build() {
    if (!canvas || !data.length) return
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'doughnut', data:{ labels:data.map(d=>d.hook), datasets:[{data:data.map(d=>d.blocks),backgroundColor:data.map((_,i)=>P[i%P.length]),borderWidth:0}] },
      options:{responsive:true,maintainAspectRatio:false,cutout:'60%',plugins:{legend:{position:'bottom',labels:{color:'#262626',font:{weight:'700',size:11},boxWidth:10,padding:12}}}} })
  }
  $: if (canvas && data) build()
  onMount(build); onDestroy(()=>chart?.destroy())
</script>
<Card title={$t('charts.hooks')}><div class="w"><canvas bind:this={canvas}></canvas></div></Card>
<style>.w{height:260px;position:relative;}</style>
