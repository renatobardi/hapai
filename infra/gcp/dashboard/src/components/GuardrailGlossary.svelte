<script>
  // hooks: [{hook, blocks}] from BigQuery
  const { hooks = [], onselect = () => {} } = $props()

  const GUARDRAILS = [
    {
      id: 'guard-branch',
      name: 'Branch Protection',
      icon: '🔒',
      description: 'Prevents commits, pushes, merges, and rebases directly on protected branches like main and master.',
      when: 'Triggers when the AI tries to commit or push to a protected branch.',
      action: 'Create a feature branch first: git checkout -b feat/your-feature',
      severity: 'high',
    },
    {
      id: 'guard-files',
      name: 'File Protection',
      icon: '📄',
      description: 'Blocks writes to sensitive files including .env files, lockfiles (package-lock.json, poetry.lock), and CI/CD workflow files (.github/workflows/).',
      when: 'Triggers when the AI attempts to write, edit, or modify a protected file — including via shell redirects or scripting APIs.',
      action: 'Edit these files manually. They should not be modified by AI assistants.',
      severity: 'high',
    },
    {
      id: 'guard-destructive',
      name: 'Destructive Commands',
      icon: '💣',
      description: 'Blocks dangerous operations: rm -rf on critical paths, force-push (git push --force), SQL DROP/TRUNCATE statements, system-level destructive commands, and fork bombs.',
      when: 'Triggers when the AI runs or proposes irreversible operations that could destroy data.',
      action: 'Use safer alternatives: git push --force-with-lease instead of --force. Avoid rm -rf on project roots.',
      severity: 'critical',
    },
    {
      id: 'guard-blast-radius',
      name: 'Blast Radius',
      icon: '📦',
      description: 'Warns or blocks when a single commit touches too many files or spans multiple packages in a monorepo. Encourages focused, reviewable commits.',
      when: 'Triggers before git commit when staged files exceed the configured threshold (default: 10 files or 2 packages).',
      action: 'Split into smaller, focused commits. Use git add -p to stage selectively.',
      severity: 'medium',
    },
    {
      id: 'guard-commit-msg',
      name: 'Commit Message',
      icon: '✉️',
      description: 'Blocks commits that contain AI attribution strings like "Co-Authored-By: Claude", "Generated with Claude", or references to Anthropic email addresses.',
      when: 'Triggers when the commit message contains patterns that reveal AI authorship.',
      action: 'Remove AI attribution from commit messages. Write clean, human-style commit messages.',
      severity: 'medium',
    },
    {
      id: 'guard-uncommitted',
      name: 'Uncommitted Changes',
      icon: '⚠️',
      description: 'Warns when the AI tries to edit a file that already has uncommitted local changes, preventing accidental overwrites of work in progress.',
      when: 'Triggers on Write or Edit operations when the target file has unstaged modifications.',
      action: 'Commit or stash your changes first: git stash or git commit.',
      severity: 'low',
    },
    {
      id: 'guard-branch-taxonomy',
      name: 'Branch Naming',
      icon: '🏷️',
      description: 'Enforces branch naming conventions. Branches must use approved prefixes: feat/, fix/, chore/, docs/, refactor/, test/, perf/, style/, ci/, build/, release/, hotfix/.',
      when: 'Triggers when creating a branch without a valid taxonomy prefix.',
      action: 'Use: git checkout -b feat/your-feature or git checkout -b fix/the-bug',
      severity: 'low',
    },
  ]

  const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 }
  const severityColors = {
    critical: '#ef4444',
    high:     '#f97316',
    medium:   '#f59e0b',
    low:      '#6b7280',
  }

  function countFor(id) {
    const h = hooks.find(h => h.hook === id)
    return h ? h.blocks : null
  }

  let expanded = $state(null)

  function toggle(id) {
    expanded = expanded === id ? null : id
  }
</script>

<div class="gl-wrap">
  <div class="gl-header">
    <h2 class="gl-title">Guardrail Reference</h2>
    <p class="gl-subtitle">What each guard does, when it fires, and what to do when it blocks you</p>
  </div>

  <div class="gl-list">
    {#each GUARDRAILS.sort((a,b) => severityOrder[a.severity] - severityOrder[b.severity]) as g}
      {@const count = countFor(g.id)}
      {@const isExpanded = expanded === g.id}

      <div class="gl-item {isExpanded ? 'expanded' : ''}">
        <button class="gl-row" onclick={() => toggle(g.id)}>
          <span class="gl-icon">{g.icon}</span>
          <div class="gl-row-info">
            <span class="gl-name">{g.name}</span>
            <span class="gl-id">{g.id}</span>
          </div>
          <div class="gl-row-meta">
            {#if count != null}
              <span class="gl-count" style="color: {count > 0 ? '#ef4444' : '#22c55e'}">
                {count > 0 ? `${count.toLocaleString()} blocked` : 'No blocks'}
              </span>
            {:else}
              <span class="gl-count inactive">Not triggered</span>
            {/if}
            <span class="gl-severity" style="background: {severityColors[g.severity]}20; color: {severityColors[g.severity]}">
              {g.severity}
            </span>
          </div>
          <span class="gl-chevron">{isExpanded ? '▲' : '▼'}</span>
        </button>

        {#if isExpanded}
          <div class="gl-detail">
            <div class="gl-section">
              <div class="gl-section-label">What it does</div>
              <p>{g.description}</p>
            </div>
            <div class="gl-section">
              <div class="gl-section-label">When it triggers</div>
              <p>{g.when}</p>
            </div>
            <div class="gl-section">
              <div class="gl-section-label">What to do</div>
              <p class="gl-action">{g.action}</p>
            </div>
            {#if count != null && count > 0}
              <button class="gl-drill-btn" onclick={() => onselect(g.id)}>
                View {count.toLocaleString()} blocked events →
              </button>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  .gl-wrap { display: flex; flex-direction: column; gap: 16px; }
  .gl-header { display: flex; flex-direction: column; gap: 4px; }
  .gl-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--color-text-muted, #666); margin: 0; }
  .gl-subtitle { font-size: 13px; color: var(--color-text-muted, #888); margin: 0; }

  .gl-list { display: flex; flex-direction: column; gap: 0; border: 1px solid var(--color-border, #e5e7eb); }

  .gl-item { border-bottom: 1px solid var(--color-border, #e5e7eb); }
  .gl-item:last-child { border-bottom: none; }
  .gl-item.expanded { background: #fafafa; }

  .gl-row {
    display: flex; align-items: center; gap: 12px;
    width: 100%; padding: 14px 16px;
    background: none; border: none; cursor: pointer; text-align: left;
    transition: background .1s;
  }
  .gl-row:hover { background: #f5f5f5; }

  .gl-icon { font-size: 20px; flex-shrink: 0; width: 28px; text-align: center; }

  .gl-row-info { flex: 1; min-width: 0; }
  .gl-name { display: block; font-size: 14px; font-weight: 600; color: var(--color-text, #111); }
  .gl-id   { display: block; font-size: 11px; font-family: monospace; color: var(--color-text-muted, #888); margin-top: 2px; }

  .gl-row-meta { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
  .gl-count { font-size: 12px; font-weight: 600; }
  .gl-count.inactive { color: var(--color-text-muted, #aaa); font-weight: 400; }

  .gl-severity {
    font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em;
    padding: 2px 7px; border-radius: 2px;
  }

  .gl-chevron { font-size: 10px; color: var(--color-text-muted, #aaa); flex-shrink: 0; }

  .gl-detail { padding: 16px 20px 20px 56px; display: flex; flex-direction: column; gap: 14px; }
  .gl-section { display: flex; flex-direction: column; gap: 4px; }
  .gl-section-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .07em; color: var(--color-text-muted, #888); }
  .gl-section p { font-size: 13px; line-height: 1.6; color: var(--color-text, #333); margin: 0; }
  .gl-action { font-family: monospace; background: #f0f0f0; padding: 6px 10px; font-size: 12px !important; }

  .gl-drill-btn {
    align-self: flex-start;
    background: none; border: 1px solid var(--color-deny, #ef4444);
    color: var(--color-deny, #ef4444); padding: 6px 14px;
    font-size: 12px; font-weight: 600; cursor: pointer;
    transition: background .1s, color .1s;
  }
  .gl-drill-btn:hover { background: var(--color-deny, #ef4444); color: #fff; }
</style>
