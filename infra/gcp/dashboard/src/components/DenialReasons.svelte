<script>
  const { data = [], onselect = () => {} } = $props()

  // Group reasons by hook
  let byHook = $derived(() => {
    const map = {}
    for (const r of data) {
      if (!map[r.hook]) map[r.hook] = []
      map[r.hook].push(r)
    }
    // Sort hooks by total count descending
    return Object.entries(map)
      .map(([hook, reasons]) => ({
        hook,
        total: reasons.reduce((s, r) => s + r.count, 0),
        reasons: reasons.sort((a, b) => b.count - a.count).slice(0, 5),
      }))
      .sort((a, b) => b.total - a.total)
  })

  const maxCount = $derived(data.length ? Math.max(...data.map(r => r.count)) : 1)

  function hookLabel(hook) {
    const labels = {
      'guard-branch':        'Branch Protection',
      'guard-files':         'File Protection',
      'guard-destructive':   'Destructive Commands',
      'guard-blast-radius':  'Blast Radius',
      'guard-commit-msg':    'Commit Message',
      'guard-uncommitted':   'Uncommitted Changes',
      'guard-branch-taxonomy': 'Branch Naming',
    }
    return labels[hook] || hook
  }

  function shortReason(reason) {
    if (!reason) return '–'
    // Strip "hapai: " prefix
    return reason.replace(/^hapai:\s*/i, '').slice(0, 90) + (reason.length > 90 ? '…' : '')
  }
</script>

<div class="dr-wrap">
  <div class="dr-header">
    <h2 class="dr-title">Top Denial Reasons</h2>
    <p class="dr-subtitle">Most common messages per guardrail — reveals patterns in blocked actions</p>
  </div>

  {#if !data.length}
    <div class="dr-empty">No denials recorded yet. Guardrails are passing everything through.</div>
  {:else}
    <div class="dr-list">
      {#each byHook() as group}
        <div class="dr-group">
          <button class="dr-hook-btn" onclick={() => onselect(group.hook)}>
            <span class="dr-hook-name">{hookLabel(group.hook)}</span>
            <span class="dr-hook-count">{group.total.toLocaleString()} denials</span>
          </button>
          <div class="dr-reasons">
            {#each group.reasons as r}
              <div class="dr-reason">
                <div class="dr-bar-wrap">
                  <div class="dr-bar" style="width: {Math.round((r.count / maxCount) * 100)}%"></div>
                </div>
                <div class="dr-reason-text">{shortReason(r.reason)}</div>
                <div class="dr-reason-count">{r.count.toLocaleString()}</div>
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .dr-wrap { display: flex; flex-direction: column; gap: 16px; }
  .dr-header { display: flex; flex-direction: column; gap: 4px; }
  .dr-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--color-text-muted, #666); margin: 0; }
  .dr-subtitle { font-size: 13px; color: var(--color-text-muted, #888); margin: 0; }
  .dr-empty { padding: 32px 0; text-align: center; color: var(--color-text-muted, #888); font-size: 14px; }

  .dr-list { display: flex; flex-direction: column; gap: 20px; }

  .dr-group { border: 1px solid var(--color-border, #e5e7eb); }

  .dr-hook-btn {
    display: flex; align-items: center; justify-content: space-between;
    width: 100%; padding: 10px 14px;
    background: var(--color-off-white, #f9fafb);
    border: none; border-bottom: 1px solid var(--color-border, #e5e7eb);
    cursor: pointer; text-align: left;
    transition: background .1s;
  }
  .dr-hook-btn:hover { background: #f0f0f0; }
  .dr-hook-name { font-size: 13px; font-weight: 700; color: var(--color-text, #111); text-transform: uppercase; letter-spacing: .05em; }
  .dr-hook-count { font-size: 12px; font-weight: 600; color: var(--color-deny, #ef4444); }

  .dr-reasons { display: flex; flex-direction: column; }
  .dr-reason {
    display: grid;
    grid-template-columns: 80px 1fr auto;
    align-items: center; gap: 12px;
    padding: 9px 14px;
    border-bottom: 1px solid var(--color-border, #f0f0f0);
  }
  .dr-reason:last-child { border-bottom: none; }

  .dr-bar-wrap { height: 6px; background: #f0f0f0; overflow: hidden; }
  .dr-bar { height: 100%; background: var(--color-deny, #ef4444); opacity: .7; transition: width .3s; }

  .dr-reason-text { font-size: 13px; color: var(--color-text, #333); line-height: 1.4; }
  .dr-reason-count { font-size: 13px; font-weight: 700; color: var(--color-text-muted, #666); white-space: nowrap; }
</style>
