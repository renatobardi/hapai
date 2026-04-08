<script>
  import { onMount, onDestroy } from 'svelte'
  import { Chart, BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend } from 'chart.js'
  Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend)
  export let data = []
  let canvas; let chart
  const scales = { x: { ticks:{color:'#757575',font:{size:11}}, grid:{color:'#f0f0f0'}, border:{color:'#f0f0f0'} }, y: { ticks:{color:'#757575',font:{size:11}}, grid:{color:'#f0f0f0'}, border:{color:'#f0f0f0'} } }
  function build() {
    if (!canvas || !data.length) return
    const byDay = {}
    for (const r of data) { if (!byDay[r.day]) byDay[r.day]={denies:0,warns:0}; if(r.event==='deny') byDay[r.day].denies=r.count; if(r.event==='warn') byDay[r.day].warns=r.count }
    const s = Object.entries(byDay).sort(([a],[b])=>a.localeCompare(b))
    if (chart) chart.destroy()
    chart = new Chart(canvas, { type:'bar', data:{ labels:s.map(([d])=>d), datasets:[
      {label:'Denials',data:s.map(([,v])=>v.denies),backgroundColor:'rgba(192,57,43,0.85)',borderRadius:0,borderWidth:0},
      {label:'Warnings',data:s.map(([,v])=>v.warns),backgroundColor:'rgba(230,126,34,0.7)',borderRadius:0,borderWidth:0},
    ]}, options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{labels:{color:'#262626',font:{weight:'700',size:12},boxWidth:12}}},scales} })
  }
  $: if (canvas && data) build()
  onMount(build); onDestroy(()=>chart?.destroy())
</script>
<div class="card"><div class="card-title">Event Timeline — 30 days</div><div class="w"><canvas bind:this={canvas}></canvas></div></div>
<style>.w{height:220px;position:relative;}</style>
