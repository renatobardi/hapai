<script>
  import { onMount, onDestroy } from 'svelte'
  import { t } from '../stores/i18n.js'

  let activeSection = $state('what-is-hapai')
  let observer
  const intersecting = new Set()

  const navGroups = [
    {
      labelKey: 'docs.nav.groups.gettingStarted',
      sections: [
        { id: 'what-is-hapai', key: 'whatIs' },
        { id: 'quick-start',   key: 'quickStart' },
      ]
    },
    {
      labelKey: 'docs.nav.groups.configuration',
      sections: [
        { id: 'guardrails',    key: 'guardrails' },
        { id: 'configuration', key: 'configuration' },
        { id: 'automations',   key: 'automations' },
      ]
    },
    {
      labelKey: 'docs.nav.groups.reference',
      sections: [
        { id: 'cli-commands',  key: 'cliCommands' },
        { id: 'export',        key: 'export' },
      ]
    },
    {
      labelKey: 'docs.nav.groups.cloud',
      sections: [
        { id: 'analytics',     key: 'analytics' },
        { id: 'cloud-logging', key: 'cloudLogging' },
      ]
    },
    {
      labelKey: 'docs.nav.groups.help',
      sections: [
        { id: 'faq', key: 'faq' },
      ]
    },
  ]

  onMount(() => {
    observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) intersecting.add(e.target)
          else intersecting.delete(e.target)
        }
        if (intersecting.size === 0) return
        const top = [...intersecting].sort((a, b) => a.offsetTop - b.offsetTop)[0]
        activeSection = top.id
      },
      { rootMargin: '-20% 0px -70% 0px' }
    )
    document.querySelectorAll('.docs-section[id]').forEach(s => observer.observe(s))
  })

  onDestroy(() => observer?.disconnect())
</script>

<div class="docs-container">
  <aside class="sidebar">
    <nav class="sidebar-nav">
      {#each navGroups as group}
        <p class="nav-group-label">{$t(group.labelKey)}</p>
        {#each group.sections as s}
          <a href="#/docs"
             class="sidebar-link"
             class:active={activeSection === s.id}
             onclick={(e) => {
               e.preventDefault()
               document.getElementById(s.id)?.scrollIntoView({ behavior: 'smooth' })
             }}>
            {$t(`docs.nav.${s.key}`)}
          </a>
        {/each}
      {/each}
    </nav>
  </aside>

  <main class="content">
    <section id="what-is-hapai" class="docs-section">
      <h2>{$t('docs.sections.whatIs.heading')}</h2>
      <p>{$t('docs.sections.whatIs.p1')}</p>
      <p>{$t('docs.sections.whatIs.p2')}</p>
      <p><strong>{$t('docs.sections.whatIs.p3')}</strong></p>
    </section>

    <section id="quick-start" class="docs-section">
      <h2>{$t('docs.sections.quickStart.heading')}</h2>
      <pre><code># Clone
git clone https://github.com/renatobardi/hapai.git ~/hapai

# Add to PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Verify
hapai validate</code></pre>
    </section>

    <section id="guardrails" class="docs-section">
      <h2>{$t('docs.sections.guardrails.heading')}</h2>
      <p>{$t('docs.sections.guardrails.intro')}</p>
      <ul>
        {#each $t('docs.sections.guardrails.guards') as g}
          <li>{@html g.replace(/^([^—]+)/, '<strong>$1</strong>')}</li>
        {/each}
      </ul>
      <p><strong>{$t('docs.sections.guardrails.failOpenTitle')}</strong></p>
      <ul>
        {#each $t('docs.sections.guardrails.failOpenModes') as m}
          <li><code>{m.split(' — ')[0]}</code>{m.includes(' — ') ? ' — ' + m.split(' — ')[1] : ''}</li>
        {/each}
      </ul>
    </section>

    <section id="configuration" class="docs-section">
      <h2>{$t('docs.sections.configuration.heading')}</h2>
      <p>{$t('docs.sections.configuration.intro')}</p>
      <ol>
        {#each $t('docs.sections.configuration.tiers') as tier}
          <li>{tier}</li>
        {/each}
      </ol>
      <pre><code>version: "1.0"
risk_tier: medium

guardrails:
  branch_protection:
    enabled: true
    protected: [main, master]
    fail_open: false

  commit_hygiene:
    enabled: true
    blocked_patterns:
      - "Co-Authored-By:"
      - "Generated with Claude"
    fail_open: false

  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
    fail_open: false</code></pre>
    </section>

    <section id="automations" class="docs-section">
      <h2>{$t('docs.sections.automations.heading')}</h2>
      <p>{$t('docs.sections.automations.intro')}</p>
      <pre><code>automation:
  auto_checkpoint:
    enabled: true
    squash_on_stop: true
    commit_prefix: "checkpoint:"

  auto_format:
    enabled: true
    python: "ruff format &#123;file&#125;"
    javascript: "prettier --write &#123;file&#125;"

  auto_lint:
    enabled: true
    python: "ruff check &#123;file&#125;"
    javascript: "eslint &#123;file&#125;"</code></pre>
    </section>

    <section id="cli-commands" class="docs-section">
      <h2>{$t('docs.sections.cliCommands.heading')}</h2>
      <p><strong>{$t('docs.sections.cliCommands.installation')}</strong></p>
      <pre><code>hapai install --global        # Global (~/.hapai)
hapai install --project       # Per-project
hapai validate                # Verify installation</code></pre>
      <p><strong>{$t('docs.sections.cliCommands.monitoring')}</strong></p>
      <pre><code>hapai status                  # Show active hooks
hapai audit [N]               # Show last N entries</code></pre>
      <p><strong>{$t('docs.sections.cliCommands.emergency')}</strong></p>
      <pre><code>hapai kill                    # Disable all hooks
hapai revive                  # Re-enable hooks</code></pre>
      <p><strong>{$t('docs.sections.cliCommands.export')}</strong></p>
      <pre><code>hapai export --target cursor     # Generate Cursor rules
hapai export --target copilot    # Generate Copilot rules
hapai export --all               # Export for all tools</code></pre>
    </section>

    <section id="analytics" class="docs-section">
      <h2>{$t('docs.sections.analytics.heading')}</h2>
      <p>{$t('docs.sections.analytics.intro')}</p>
      <ul>
        {#each $t('docs.sections.analytics.features') as f}
          <li>{@html f.replace(/^([^—]+)/, '<strong>$1</strong>')}</li>
        {/each}
      </ul>
      <p><strong>{$t('docs.sections.analytics.setupTitle')}</strong></p>
      <ol>
        {#each $t('docs.sections.analytics.setup') as s}
          <li>{s}</li>
        {/each}
      </ol>
    </section>

    <section id="cloud-logging" class="docs-section">
      <h2>{$t('docs.sections.cloudLogging.heading')}</h2>
      <p>{$t('docs.sections.cloudLogging.p1')}</p>
      <p><strong>{$t('docs.sections.cloudLogging.archTitle')}</strong></p>
      <pre><code>hapai audit logs (local)
    ↓
GitHub Actions OIDC (keyless auth)
    ↓
Cloud Storage bucket
    ↓
Cloud Function (triggered on upload)
    ↓
BigQuery dataset
    ↓
Analytics Dashboard</code></pre>
      <p><strong>{$t('docs.sections.cloudLogging.enableTitle')}</strong></p>
      <pre><code>gcp:
  enabled: true
  project_id: your-gcp-project
  bucket: hapai-audit-username
  region: us-east1
  retention_days: 90</code></pre>
      <p><strong>{$t('docs.sections.cloudLogging.syncTitle')}</strong></p>
      <pre><code>hapai sync                 # Manual sync
hapai sync --dry-run       # Preview sync</code></pre>
    </section>

    <section id="export" class="docs-section">
      <h2>{$t('docs.sections.export.heading')}</h2>
      <p>{$t('docs.sections.export.p1')}</p>
      <table>
        <thead>
          <tr>
            <th>{$t('docs.sections.export.cols.tool')}</th>
            <th>{$t('docs.sections.export.cols.file')}</th>
            <th>{$t('docs.sections.export.cols.command')}</th>
          </tr>
        </thead>
        <tbody>
          <tr><td>Cursor</td><td><code>.cursor/rules/hapai.mdc</code></td><td><code>hapai export --target cursor</code></td></tr>
          <tr><td>Copilot</td><td><code>.github/copilot-instructions.md</code></td><td><code>hapai export --target copilot</code></td></tr>
          <tr><td>Windsurf</td><td><code>.windsurf/rules/hapai.md</code></td><td><code>hapai export --target windsurf</code></td></tr>
          <tr><td>Devin.ai</td><td><code>AGENTS.md</code></td><td><code>hapai export --target devin</code></td></tr>
          <tr><td>Trae</td><td><code>.trae/rules/hapai.md</code></td><td><code>hapai export --target trae</code></td></tr>
        </tbody>
      </table>
      <p>{$t('docs.sections.export.exportAll')}</p>
      <pre><code>hapai export --all</code></pre>
    </section>

    <section id="faq" class="docs-section">
      <h2>{$t('docs.sections.faq.heading')}</h2>
      {#each $t('docs.sections.faq.questions') as qa}
        <p><strong>Q: {qa.q}</strong><br/>A: {qa.a}</p>
      {/each}
    </section>

    <section class="footer">
      <p>{$t('docs.sections.footer')} <a href="https://github.com/renatobardi/hapai" target="_blank">hapai on GitHub</a>.</p>
    </section>
  </main>
</div>

<style>
  .docs-container { display: flex; min-height: calc(100vh - 80px); background: var(--color-off-white); }

  .sidebar { width: 200px; background: var(--color-white); border-right: 1px solid var(--color-light-gray); padding: var(--space-3); position: sticky; top: 80px; height: calc(100vh - 80px); overflow-y: auto; }
  .sidebar-nav { display: flex; flex-direction: column; gap: 2px; }
  .nav-group-label { font-size: 10px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--color-meta-gray); padding: 10px 8px 4px; margin: 0; }
  .nav-group-label:first-child { padding-top: 0; }
  .sidebar-link { font-size: 12px; font-weight: var(--weight-normal); color: var(--color-meta-gray); text-decoration: none; padding: 6px 8px; border-radius: 2px; transition: all var(--transition-fast); }
  .sidebar-link:hover { background: var(--color-off-white); color: var(--color-near-black); }
  .sidebar-link.active { background: var(--color-light-gray); color: var(--color-near-black); font-weight: var(--weight-bold); }

  .content { flex: 1; padding: var(--space-6) var(--space-4); max-width: 900px; margin: 0 auto; }

  .docs-section { margin-bottom: var(--space-8); padding-bottom: var(--space-4); border-bottom: 1px solid var(--color-light-gray); }
  .docs-section:last-of-type { border-bottom: none; }

  .docs-section h2 { font-size: 24px; font-weight: var(--weight-black); color: var(--color-near-black); margin-bottom: var(--space-2); letter-spacing: -0.01em; }
  .docs-section p { font-size: 14px; line-height: 1.6; color: var(--color-near-black); margin-bottom: var(--space-2); }
  .docs-section ul, .docs-section ol { margin-left: var(--space-2); margin-bottom: var(--space-2); }
  .docs-section li { margin-bottom: var(--space-1); }

  code { background: var(--color-light-gray); padding: 2px 6px; border-radius: 2px; font-family: 'Courier New', monospace; font-size: 12px; color: var(--color-near-black); }

  pre { background: var(--color-near-black); color: #fff; padding: var(--space-2); border-radius: 2px; overflow-x: auto; margin-bottom: var(--space-2); }
  pre code { background: none; color: inherit; padding: 0; }

  table { width: 100%; border-collapse: collapse; margin-bottom: var(--space-2); }
  th, td { padding: var(--space-1); text-align: left; border-bottom: 1px solid var(--color-light-gray); font-size: 13px; }
  th { background: var(--color-light-gray); font-weight: var(--weight-bold); }

  a { color: var(--color-blue); text-decoration: none; }
  a:hover { text-decoration: underline; }

  .footer { text-align: center; color: var(--color-meta-gray); font-size: 12px; margin-top: var(--space-6); }

  @media (max-width: 768px) {
    .docs-container { flex-direction: column; }
    .sidebar { width: 100%; height: auto; position: relative; top: 0; border-right: none; border-bottom: 1px solid var(--color-light-gray); }
    .content { padding: var(--space-3); }
  }
</style>
