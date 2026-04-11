<script>
  import { t } from '../stores/i18n.js'
  import Badge from './Badge.svelte'

  let {
    event   = null,   // selected event object
    events  = [],     // full list for prev/next navigation
    onclose = null    // () => void
  } = $props()

  let currentIdx = $state(0)

  // Sync index when the event prop changes (e.g. opened from DenialsTable row)
  // Use ts+hook+tool as composite key — object identity breaks after store reloads
  $effect(() => {
    const i = events.findIndex(e =>
      e.ts === event?.ts && e.hook === event?.hook && e.tool === event?.tool
    )
    currentIdx = i >= 0 ? i : 0
  })

  let current  = $derived(events[currentIdx] ?? event)
  let hasPrev  = $derived(currentIdx > 0)
  let hasNext  = $derived(currentIdx < events.length - 1)
  // Guard against empty events array (denials not yet loaded)
  let position = $derived(`${currentIdx + 1} ${$t('detail.of')} ${Math.max(events.length, 1)}`)

  function prev() { if (hasPrev) currentIdx-- }
  function next() { if (hasNext) currentIdx++ }

  // Close on Escape key
  $effect(() => {
    function onkey(e) { if (e.key === 'Escape') onclose?.() }
    window.addEventListener('keydown', onkey)
    return () => window.removeEventListener('keydown', onkey)
  })

  const fmtFull = ts => {
    if (!ts) return '—'
    return new Date(ts).toLocaleString(undefined, {
      month: 'short', day: 'numeric', year: 'numeric',
      hour: '2-digit', minute: '2-digit', second: '2-digit'
    })
  }
</script>

<!-- Overlay -->
<div class="overlay" onclick={onclose} role="presentation"></div>

<!-- Drawer -->
<div class="drawer" role="dialog" aria-modal="true" aria-label={$t('detail.title')}>
  <div class="drawer-header">
    <span class="drawer-title">{$t('detail.title')}</span>
    <button class="close-btn" onclick={onclose} aria-label={$t('detail.close')}>×</button>
  </div>

  {#if current}
    <div class="drawer-body">
      <div class="event-type">
        <Badge type={current.event}>{current.event}</Badge>
        <span class="timestamp">{fmtFull(current.ts)}</span>
      </div>

      <table class="meta">
        <tbody>
          <tr>
            <td class="meta-key">{$t('detail.guard')}</td>
            <td class="meta-val mono">{current.hook ?? '—'}</td>
          </tr>
          <tr>
            <td class="meta-key">{$t('detail.tool')}</td>
            <td class="meta-val mono">{current.tool ?? '—'}</td>
          </tr>
          {#if current.project}
            <tr>
              <td class="meta-key">{$t('detail.project')}</td>
              <td class="meta-val mono">{current.project}</td>
            </tr>
          {/if}
        </tbody>
      </table>

      <div class="reason-block">
        <div class="reason-label">{$t('detail.reason')}</div>
        <div class="reason-body">{current.result || '—'}</div>
      </div>
    </div>

    <div class="drawer-footer">
      <span class="position">{position}</span>
      <div class="nav">
        <button onclick={prev} disabled={!hasPrev}>{$t('detail.prev')}</button>
        <button onclick={next} disabled={!hasNext}>{$t('detail.next')}</button>
      </div>
    </div>
  {/if}
</div>

<style>
  .overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.25);
    z-index: 100; animation: fade-in 150ms ease;
  }
  @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }

  div.drawer {
    position: fixed; top: 0; right: 0; bottom: 0;
    width: 400px; max-width: 92vw;
    background: var(--color-white);
    border-left: 1px solid var(--color-border-medium);
    box-shadow: var(--shadow-lg);
    z-index: 101;
    display: flex; flex-direction: column;
    animation: slide-in 200ms ease;
  }
  @keyframes slide-in {
    from { transform: translateX(100%); opacity: 0; }
    to   { transform: translateX(0);    opacity: 1; }
  }

  .drawer-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--color-light-gray);
    background: var(--color-off-white);
    flex-shrink: 0;
  }
  .drawer-title {
    font-size: 10px; font-weight: var(--weight-bold); text-transform: uppercase;
    letter-spacing: 0.1em; color: var(--color-meta-gray);
  }
  .close-btn {
    background: none; border: none; font-size: 20px; line-height: 1;
    color: var(--color-meta-gray); cursor: pointer; padding: 2px 6px;
    transition: color var(--transition-fast);
  }
  .close-btn:hover { color: var(--color-near-black); }

  .drawer-body { flex: 1; overflow-y: auto; padding: var(--space-3); display: flex; flex-direction: column; gap: var(--space-3); }

  .event-type { display: flex; align-items: center; gap: var(--space-2); flex-wrap: wrap; }
  .timestamp { font-size: 12px; color: var(--color-meta-gray); }

  .meta { width: 100%; border-collapse: collapse; }
  .meta tr { border-bottom: 1px solid var(--color-light-gray); }
  .meta tr:last-child { border-bottom: none; }
  .meta-key {
    width: 80px; padding: 10px 0; font-size: 11px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.06em; color: var(--color-meta-gray);
    vertical-align: top;
  }
  .meta-val { padding: 10px 0 10px 12px; font-size: 13px; color: var(--color-near-black); word-break: break-all; }

  .reason-block {
    border: 1px solid var(--color-light-gray);
    border-left: 3px solid var(--color-deny);
    padding: var(--space-2);
  }
  .reason-label {
    font-size: 10px; font-weight: var(--weight-bold); text-transform: uppercase;
    letter-spacing: 0.1em; color: var(--color-meta-gray); margin-bottom: 8px;
  }
  .reason-body { font-size: 13px; color: var(--color-near-black); white-space: pre-wrap; word-break: break-word; line-height: 1.6; }

  .drawer-footer {
    display: flex; align-items: center; justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-top: 1px solid var(--color-light-gray);
    background: var(--color-off-white);
    flex-shrink: 0;
  }
  .position { font-size: 11px; color: var(--color-meta-gray); }
  .nav { display: flex; gap: var(--space-1); }
  .nav button {
    background: none; border: 1px solid var(--color-border-medium);
    padding: 5px 12px; font-size: 11px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-near-black);
    cursor: pointer; transition: all var(--transition-fast);
  }
  .nav button:hover:not(:disabled) { background: var(--color-near-black); color: var(--color-white); border-color: var(--color-near-black); }
  .nav button:disabled { opacity: 0.3; cursor: default; }
</style>
