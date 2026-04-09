<script>
  let activeSection = $state('what-is-hapai')
  const sections = [
    { id: 'what-is-hapai', label: 'What is hapai' },
    { id: 'quick-start', label: 'Quick Start' },
    { id: 'guardrails', label: 'Guardrails' },
    { id: 'configuration', label: 'Configuration' },
    { id: 'automations', label: 'Automations' },
    { id: 'cli-commands', label: 'CLI Commands' },
    { id: 'analytics', label: 'Analytics' },
    { id: 'cloud-logging', label: 'Cloud Logging' },
    { id: 'export', label: 'Export' },
    { id: 'faq', label: 'FAQ' }
  ]
</script>

<div class="docs-container">
  <aside class="sidebar">
    <nav class="sidebar-nav">
      {#each sections as section}
        <a href="#/docs"
           class="sidebar-link"
           class:active={activeSection === section.id}
           onclick={(e) => {
             e.preventDefault()
             activeSection = section.id
             document.getElementById(section.id)?.scrollIntoView({ behavior: 'smooth' })
           }}>
          {section.label}
        </a>
      {/each}
    </nav>
  </aside>

  <main class="content">
    <section id="what-is-hapai" class="docs-section">
      <h2>What is hapai</h2>
      <p>hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations <strong>before execution</strong> — not probabilistic prompts that get ignored.</p>
      <p>Why this matters: AI coding tools frequently ignore markdown instructions. They commit to protected branches, edit secrets files, run destructive commands, and add AI attribution despite explicit rules. LLMs see markdown as suggestions, not requirements.</p>
      <p><strong>The solution:</strong> Deterministic enforcement via hooks running before the action, not after.</p>
    </section>

    <section id="quick-start" class="docs-section">
      <h2>Quick Start</h2>
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
      <h2>Guardrails</h2>
      <p>Guardrails block violations before execution. All support <code>fail_open</code>:</p>
      <ul>
        <li><strong>Branch Protection</strong> — Commits/pushes to protected branches (main, master)</li>
        <li><strong>Branch Taxonomy</strong> — Enforces naming conventions (feat/, fix/, chore/, etc.)</li>
        <li><strong>Commit Hygiene</strong> — Blocks Co-Authored-By, AI mentions, "Generated with Claude"</li>
        <li><strong>File Protection</strong> — Prevents writes to .env, lockfiles, CI workflow files</li>
        <li><strong>Destructive Commands</strong> — Blocks <code>rm -rf</code>, <code>git push --force</code>, <code>DROP TABLE</code>, etc.</li>
        <li><strong>Blast Radius</strong> — Warns on large commits touching too many files</li>
        <li><strong>Uncommitted Changes</strong> — Prevents overwriting your uncommitted work</li>
        <li><strong>PR Review</strong> — Background code review on all PRs (optional)</li>
        <li><strong>Git Workflow</strong> — Trunk-based or GitFlow enforcement</li>
      </ul>
      <p><strong>fail_open modes:</strong></p>
      <ul>
        <li><code>fail_open: false</code> — Block execution, show error</li>
        <li><code>fail_open: true</code> — Warn but allow (soft constraints)</li>
      </ul>
    </section>

    <section id="configuration" class="docs-section">
      <h2>Configuration</h2>
      <p>YAML-based with three-tier fallback:</p>
      <ol>
        <li>Project <code>./hapai.yaml</code> (overrides all)</li>
        <li>Global <code>~/.hapai/hapai.yaml</code></li>
        <li>Defaults <code>hapai.defaults.yaml</code></li>
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
      <h2>Automations</h2>
      <p>Automations run after execution. Enable in <code>hapai.yaml</code>:</p>
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
      <h2>CLI Commands</h2>
      <p><strong>Installation:</strong></p>
      <pre><code>hapai install --global        # Global (~/.hapai)
hapai install --project       # Per-project
hapai validate                # Verify installation</code></pre>
      <p><strong>Monitoring:</strong></p>
      <pre><code>hapai status                  # Show active hooks
hapai audit [N]               # Show last N entries</code></pre>
      <p><strong>Emergency:</strong></p>
      <pre><code>hapai kill                    # Disable all hooks
hapai revive                  # Re-enable hooks</code></pre>
      <p><strong>Export:</strong></p>
      <pre><code>hapai export --target cursor     # Generate Cursor rules
hapai export --target copilot    # Generate Copilot rules
hapai export --all               # Export for all tools</code></pre>
    </section>

    <section id="analytics" class="docs-section">
      <h2>Analytics Dashboard</h2>
      <p>This dashboard displays real-time guardrail events from your audit logs:</p>
      <ul>
        <li><strong>Timeline</strong> — Daily denial/warning counts (30-day rolling window)</li>
        <li><strong>Top Blocking Hooks</strong> — Which guardrails are most active</li>
        <li><strong>Recent Events</strong> — Live feed of denials and warnings</li>
        <li><strong>Tool Distribution</strong> — Which tools trigger guards most</li>
        <li><strong>Project Breakdown</strong> — Per-project statistics</li>
        <li><strong>Deny Rate Trend</strong> — Historical analysis</li>
      </ul>
      <p><strong>Setup:</strong></p>
      <ol>
        <li>Create Firebase project with GitHub OAuth</li>
        <li>Set GitHub Actions secrets (VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID)</li>
        <li>Push to main → GitHub Actions builds and deploys to GitHub Pages</li>
        <li>Dashboard live at: <code>https://owner.github.io/repo/</code></li>
      </ol>
    </section>

    <section id="cloud-logging" class="docs-section">
      <h2>Cloud Logging (Optional)</h2>
      <p>Sync audit logs to GCP for enterprise analytics and compliance.</p>
      <p><strong>Architecture:</strong></p>
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
      <p><strong>Enable in hapai.yaml:</strong></p>
      <pre><code>gcp:
  enabled: true
  project_id: your-gcp-project
  bucket: hapai-audit-username
  region: us-east1
  retention_days: 90</code></pre>
      <p><strong>Sync:</strong></p>
      <pre><code>hapai sync                 # Manual sync
hapai sync --dry-run       # Preview sync</code></pre>
    </section>

    <section id="export" class="docs-section">
      <h2>Export to Other Tools</h2>
      <p>hapai exports guardrails to 8 different AI coding tools:</p>
      <table>
        <thead>
          <tr>
            <th>Tool</th>
            <th>File</th>
            <th>Command</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Cursor</td>
            <td><code>.cursor/rules/hapai.mdc</code></td>
            <td><code>hapai export --target cursor</code></td>
          </tr>
          <tr>
            <td>Copilot</td>
            <td><code>.github/copilot-instructions.md</code></td>
            <td><code>hapai export --target copilot</code></td>
          </tr>
          <tr>
            <td>Windsurf</td>
            <td><code>.windsurf/rules/hapai.md</code></td>
            <td><code>hapai export --target windsurf</code></td>
          </tr>
          <tr>
            <td>Devin.ai</td>
            <td><code>AGENTS.md</code></td>
            <td><code>hapai export --target devin</code></td>
          </tr>
          <tr>
            <td>Trae</td>
            <td><code>.trae/rules/hapai.md</code></td>
            <td><code>hapai export --target trae</code></td>
          </tr>
        </tbody>
      </table>
      <p>Export all tools at once:</p>
      <pre><code>hapai export --all</code></pre>
    </section>

    <section id="faq" class="docs-section">
      <h2>FAQ</h2>
      <p><strong>Q: Do hooks affect Claude Code performance?</strong><br/>
      A: Minimal. Each hook runs in &lt;100ms. PreToolUse has 7s timeout, PostToolUse has 5s timeout.</p>

      <p><strong>Q: How do I temporarily disable a guardrail?</strong><br/>
      A: Edit <code>hapai.yaml</code> and set <code>enabled: false</code> for that guardrail, or use <code>hapai kill</code> to disable all hooks.</p>

      <p><strong>Q: Can I create custom guardrails?</strong><br/>
      A: Yes. Create a script in <code>~/.hapai/hooks/pre-tool-use/my-guard.sh</code> and register it in <code>~/.claude/settings.json</code>.</p>

      <p><strong>Q: Where are audit logs stored?</strong><br/>
      A: Local: <code>~/.hapai/audit.jsonl</code> (append-only). Cloud: BigQuery (if GCP sync enabled).</p>

      <p><strong>Q: How do I see what hooks are doing?</strong><br/>
      A: Use <code>hapai audit</code> to see recent entries, or <code>tail -f ~/.hapai/audit.jsonl</code> to stream live.</p>
    </section>

    <section class="footer">
      <p>For detailed setup guides, see <a href="https://github.com/renatobardi/hapai" target="_blank">hapai on GitHub</a>.</p>
    </section>
  </main>
</div>

<style>
  .docs-container { display: flex; min-height: calc(100vh - 80px); background: var(--color-off-white); }

  .sidebar { width: 200px; background: var(--color-white); border-right: 1px solid var(--color-light-gray); padding: var(--space-3); position: sticky; top: 80px; height: calc(100vh - 80px); overflow-y: auto; }
  .sidebar-nav { display: flex; flex-direction: column; gap: var(--space-1); }
  .sidebar-link { font-size: 12px; font-weight: var(--weight-normal); color: var(--color-meta-gray); text-decoration: none; padding: 6px 8px; border-radius: 2px; transition: all 150ms; }
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
