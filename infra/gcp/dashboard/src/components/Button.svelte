<script>
  export let variant = 'primary'
  export let size = 'md'
  export let disabled = false
  export let type = 'button'
</script>
<button {type} {disabled} class="btn btn-{variant} btn-{size}">
  <slot />
</button>
<style>
  .btn {
    font-family: var(--font); border: none; cursor: pointer;
    font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.05em;
    display: inline-flex; align-items: center; gap: 8px;
    transition: background var(--transition-fast), color var(--transition-fast), border-color var(--transition-fast);
  }
  .btn:disabled { cursor: default; }

  /* Sizes */
  .btn-sm  { padding: 6px 14px;  font-size: 12px; }
  .btn-md  { padding: 8px 20px;  font-size: 13px; }
  .btn-lg  { padding: 12px 28px; font-size: 13px; letter-spacing: 0.06em; }

  /* Variants */
  .btn-primary { background: var(--color-blue); color: #fff; }
  .btn-primary:hover:not(:disabled) { background: var(--color-blue-dark); }
  .btn-primary:disabled { background: var(--color-meta-gray); }
  .btn-primary:focus-visible { outline: 2px solid var(--color-blue); outline-offset: 2px; }

  .btn-secondary {
    background: transparent; color: var(--color-meta-gray);
    border: 1px solid var(--color-border-dark);
  }
  .btn-secondary:hover { color: var(--color-white); border-color: var(--color-border-dark-hover); }

  .btn-ghost {
    background: transparent; color: #fff;
    border: 1px solid rgba(255,255,255,0.4); text-decoration: none;
  }
  .btn-ghost:hover { border-color: #fff; }
  .btn-ghost:focus-visible { outline: 2px solid #fff; outline-offset: 2px; }

  .btn-danger { background: var(--color-deny); color: #fff; }
  .btn-danger:hover:not(:disabled) { background: #a93226; }
  .btn-danger:disabled { background: var(--color-meta-gray); }
</style>
