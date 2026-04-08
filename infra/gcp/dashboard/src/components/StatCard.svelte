<script>
  export let label = ''
  export let value = 0
  export let accent = 'default' // 'deny' | 'warn' | 'default'
  export let period = 'Last 30 days'
</script>

<div class="card" class:accent-deny={accent === 'deny'} class:accent-warn={accent === 'warn'}>
  <div class="label">{label}</div>
  <div class="value" class:deny={accent === 'deny'} class:warn={accent === 'warn'}>{value}</div>
  <div class="period">{period}</div>
</div>

<style>
  .card {
    background: var(--color-white);
    border: 1px solid var(--color-light-gray);
    border-top: 3px solid var(--color-light-gray);
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .accent-deny  { border-top-color: var(--color-deny); }
  .accent-warn  { border-top-color: var(--color-warn); }

  .label {
    font-size: 11px;
    font-weight: var(--weight-bold);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--color-meta-gray);
  }

  .value {
    font-size: 56px;
    font-weight: var(--weight-light);
    color: var(--color-near-black);
    line-height: 1;
  }

  .value.deny { color: var(--color-deny); }
  .value.warn { color: var(--color-warn); }

  .period {
    font-size: 11px;
    color: var(--color-meta-gray);
    font-weight: var(--weight-normal);
  }
</style>
