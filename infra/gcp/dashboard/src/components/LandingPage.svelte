<script>
  import { signIn } from '../lib/firebase.js'
  import { navigate } from '../stores/route.js'

  let signingIn = $state(false)

  async function handleSignIn() {
    signingIn = true
    try { await signIn() } catch(e){} finally { signingIn = false }
  }

  function scrollToQuickStart() {
    document.getElementById('quick-start')?.scrollIntoView({ behavior: 'smooth' })
  }

  function fadeIn(node) {
    node.style.opacity = '0'
    node.style.transition = 'opacity 300ms ease'
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          node.style.opacity = '1'
          observer.disconnect()
        }
      },
      { threshold: 0.08 }
    )
    observer.observe(node)
    return { destroy() { observer.disconnect() } }
  }

  const guards = [
    { name: 'Branch Protection',    color: 'deny', desc: 'Blocks commits and pushes to main, master, or any protected branch.' },
    { name: 'Branch Taxonomy',      color: 'warn', desc: 'Enforces naming conventions: feat/, fix/, chore/, docs/, hotfix/.' },
    { name: 'Branch Rules',         color: 'warn', desc: 'Validates branch descriptions and origin tracking.' },
    { name: 'Commit Hygiene',       color: 'deny', desc: 'Strips AI attribution: Co-Authored-By, "Generated with Claude".' },
    { name: 'File Protection',      color: 'deny', desc: 'Prevents writes to .env, lockfiles, CI workflows, and any pattern you define.' },
    { name: 'Destructive Commands', color: 'deny', desc: 'Blocks rm -rf, git push --force, DROP TABLE, and configurable patterns.' },
    { name: 'Blast Radius',         color: 'warn', desc: 'Warns when a commit touches too many files or packages. Monorepo-aware.' },
    { name: 'Uncommitted Changes',  color: 'warn', desc: 'Prevents the AI from overwriting your uncommitted work.' },
    { name: 'PR Review',            color: 'deny', desc: 'Background code review on every PR. Optional auto-fix before blocking.' },
    { name: 'Git Workflow',         color: 'warn', desc: 'Enforces trunk-based or GitFlow model across the team.' },
    { name: 'Flow Dispatcher',      color: 'blue', desc: 'Sequential hook chains with conditional gate logic for complex workflows.' },
  ]
</script>

<!-- ─── Hero ─── -->
<section class="hero" use:fadeIn>
  <div class="hero-inner">
    <div class="hero-text">
      <h1>Your AI just pushed to main. Again.</h1>
      <p class="hero-sub">hapai is a deterministic guardrails system for AI coding assistants. Shell-based hooks that block dangerous actions before they execute — not markdown rules the AI ignores.</p>
      <div class="hero-ctas">
        <button class="btn-primary" onclick={scrollToQuickStart}>Get Started</button>
        <a class="btn-ghost" href="https://github.com/renatobardi/hapai" target="_blank" rel="noopener">View on GitHub</a>
      </div>
    </div>
    <div class="terminal" aria-label="hapai denial example">
      <div class="terminal-bar">
        <span class="dot"></span><span class="dot"></span><span class="dot"></span>
      </div>
      <pre class="terminal-body"><span class="t-prompt">$ </span>claude "push this to main"

<span class="t-deny">✗ DENY</span>  <span class="t-guard">guard-branch</span>
  Commits to protected branch 'main' are blocked.
  Switch to a feature branch:
    git checkout -b feat/your-feature

Action blocked. 0 violations allowed.</pre>
    </div>
  </div>
</section>

<!-- ─── Problem ─── -->
<section class="problem" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">The Problem</p>
    <h2>AI coding tools ignore your rules</h2>
    <div class="cards-3">
      <div class="problem-card">
        <span class="badge badge-deny">DENY</span>
        <h3>Commits to protected branches</h3>
        <p>You wrote "never push to main" in CLAUDE.md. The AI read it, acknowledged it, and pushed to main anyway. Markdown is a suggestion, not a constraint.</p>
      </div>
      <div class="problem-card">
        <span class="badge badge-deny">DENY</span>
        <h3>Destructive commands in production</h3>
        <p>rm -rf, git push --force, DROP TABLE — AI assistants will run these if the context suggests it. One bad inference, permanent damage.</p>
      </div>
      <div class="problem-card">
        <span class="badge badge-warn">WARN</span>
        <h3>Silent edits to sensitive files</h3>
        <p>Your .env got committed. Your lockfile got rewritten. Your CI workflow was modified. You didn't notice until the build broke — or worse, until it didn't.</p>
      </div>
    </div>
  </div>
</section>

<!-- ─── Solution ─── -->
<section class="solution" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">The Solution</p>
    <h2>Hooks, not prompts. Deterministic, not probabilistic.</h2>
    <div class="steps">
      <div class="step">
        <span class="step-num">01</span>
        <h3>Install in 30 seconds</h3>
        <p>Clone the repo, add to PATH, run hapai install --global. Three commands. No SDK, no server, no dependencies beyond bash and jq.</p>
      </div>
      <div class="step-divider" aria-hidden="true"></div>
      <div class="step">
        <span class="step-num">02</span>
        <h3>Hooks intercept every action</h3>
        <p>Every time your AI assistant tries to run a command, edit a file, or make a commit — hapai's shell hooks evaluate it against your rules before it executes.</p>
      </div>
      <div class="step-divider" aria-hidden="true"></div>
      <div class="step">
        <span class="step-num">03</span>
        <h3>Violations are blocked, not logged</h3>
        <p>When a rule is violated, the action is denied. The AI gets a clear error message and instructions on how to proceed correctly. No damage done.</p>
      </div>
    </div>
  </div>
</section>

<!-- ─── Guardrails ─── -->
<section class="guardrails" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">Guardrails</p>
    <h2>11 deterministic guards. Every one configurable.</h2>
    <div class="guards-grid">
      {#each guards as g}
        <div class="guard-card guard-{g.color}">
          <strong>{g.name}</strong>
          <p>{g.desc}</p>
        </div>
      {/each}
    </div>
    <p class="guards-note">Every guard supports <code>fail_open</code> mode — set to <code>true</code> for soft warnings, <code>false</code> for hard blocks.</p>
    <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>See full configuration →</a>
  </div>
</section>

<!-- ─── Ecosystem ─── -->
<section class="ecosystem" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">Ecosystem</p>
    <h2>One config. Every AI coding tool.</h2>
    <p class="tool-list">Claude Code · Cursor · GitHub Copilot · Devin · Windsurf · Trae · Antigravity</p>
    <pre class="code-block"># Export guardrails to all tools at once
hapai export --all

# Or target a specific tool
hapai export --target cursor
hapai export --target copilot</pre>
  </div>
</section>

<!-- ─── Quick Start ─── -->
<section class="quick-start" id="quick-start" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">Quick Start</p>
    <h2>Three commands. You're protected.</h2>
    <pre class="code-block"># Clone
git clone https://github.com/renatobardi/hapai.git ~/hapai

# Add to PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Verify everything works
hapai validate</pre>
    <div class="qs-links">
      <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>Want to configure guardrails?</a>
      <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>Need project-level overrides?</a>
    </div>
  </div>
</section>

<!-- ─── Analytics Preview ─── -->
<section class="analytics" use:fadeIn>
  <div class="section-inner">
    <p class="section-label analytics-label">Analytics</p>
    <h2 class="analytics-heading">See what your AI is doing.</h2>
    <p class="analytics-desc">hapai logs every action — denials, warnings, and allows — to an append-only audit trail. Sync to BigQuery for enterprise analytics, or use the built-in dashboard to visualize guardrail activity across all your projects.</p>
    <p class="analytics-features">30-day timeline · Top blocking hooks · Tool distribution · Per-project breakdown · Deny rate trends</p>
    <button class="btn-primary" onclick={handleSignIn} disabled={signingIn}>
      {signingIn ? 'Signing in…' : 'Sign in with GitHub'}
    </button>
    <p class="analytics-note">Dashboard requires GitHub authentication. Your audit data stays yours.</p>
  </div>
</section>

<!-- ─── Footer CTA ─── -->
<section class="footer-cta" use:fadeIn>
  <div class="section-inner footer-inner">
    <h2 class="footer-heading">Stop hoping the AI will follow the rules. Enforce them.</h2>
    <button class="btn-primary" onclick={scrollToQuickStart}>Get Started</button>
    <nav class="footer-links" aria-label="Footer links">
      <a href="https://github.com/renatobardi/hapai" target="_blank" rel="noopener">GitHub</a>
      <span aria-hidden="true">·</span>
      <a href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>Documentation</a>
      <span aria-hidden="true">·</span>
      <a href="https://github.com/renatobardi/hapai/blob/main/CHANGELOG.md" target="_blank" rel="noopener">Changelog</a>
    </nav>
    <p class="footer-note">hapai v1.5.1 · Pure bash. Zero dependencies. Deterministic safety.</p>
  </div>
</section>

<style>
  /* ─── Shared ─── */
  section { width: 100%; }
  .section-inner { max-width: 1200px; margin: 0 auto; padding: var(--space-8) var(--space-4); }
  .section-label { font-size: 11px; font-weight: var(--weight-bold); text-transform: uppercase; letter-spacing: 0.08em; color: var(--color-meta-gray); margin: 0 0 var(--space-2); }
  h2 { font-family: 'Space Grotesk', var(--font); font-size: 32px; font-weight: 700; margin: 0 0 var(--space-6); line-height: 1.2; }
  h3 { font-size: 16px; font-weight: var(--weight-bold); margin: var(--space-2) 0 var(--space-1); }
  p { margin: 0; line-height: 1.6; }

  .btn-primary {
    background: var(--color-blue); color: #fff;
    padding: 12px 28px; font-size: 13px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.06em;
    border: none; cursor: pointer; transition: background 150ms;
    display: inline-flex; align-items: center; gap: 8px;
  }
  .btn-primary:hover:not(:disabled) { background: var(--color-blue-dark); }
  .btn-primary:disabled { background: var(--color-meta-gray); cursor: default; }
  .btn-primary:focus-visible { outline: 2px solid var(--color-blue); outline-offset: 2px; }

  .btn-ghost {
    background: transparent; color: #fff;
    padding: 12px 28px; font-size: 13px; font-weight: var(--weight-bold);
    text-transform: uppercase; letter-spacing: 0.06em;
    border: 1px solid rgba(255,255,255,0.4); text-decoration: none;
    transition: border-color 150ms; display: inline-flex; align-items: center;
  }
  .btn-ghost:hover { border-color: #fff; }
  .btn-ghost:focus-visible { outline: 2px solid #fff; outline-offset: 2px; }

  .text-link { font-size: 13px; font-weight: var(--weight-bold); color: var(--color-blue); text-decoration: none; }
  .text-link:hover { text-decoration: underline; }

  .code-block {
    background: var(--color-near-black); color: #e8e8e8;
    padding: var(--space-3); font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 13px; line-height: 1.7; overflow-x: auto;
    margin: 0 0 var(--space-3); white-space: pre;
  }

  /* ─── Hero ─── */
  .hero { background: var(--color-black); }
  .hero-inner {
    max-width: 1200px; margin: 0 auto;
    padding: 80px var(--space-4);
    display: grid; grid-template-columns: 1fr 1fr;
    gap: var(--space-8); align-items: center;
  }
  h1 {
    font-family: 'Space Grotesk', var(--font); font-size: 48px; font-weight: 700;
    color: #fff; margin: 0 0 var(--space-3); line-height: 1.1;
  }
  .hero-sub {
    font-size: 18px; font-weight: var(--weight-light);
    color: #e8e8e8; margin: 0 0 var(--space-4); line-height: 1.6;
  }
  .hero-ctas { display: flex; gap: var(--space-2); flex-wrap: wrap; }

  .terminal { background: #1a1a1a; border: 1px solid #333; }
  .terminal-bar { background: #2a2a2a; padding: 10px 14px; display: flex; gap: 6px; align-items: center; }
  .dot { width: 10px; height: 10px; background: #444; display: block; }
  .terminal-body {
    margin: 0; padding: var(--space-3);
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 13px; line-height: 1.7; color: #ccc;
    white-space: pre; overflow-x: auto;
  }
  .t-prompt { color: var(--color-meta-gray); }
  .t-deny { color: var(--color-deny); font-weight: var(--weight-bold); }
  .t-guard { color: var(--color-meta-gray); }

  /* ─── Problem ─── */
  .problem { background: var(--color-white); }
  .cards-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-3); }
  .problem-card {
    border: 1px solid #e0e0e0; padding: var(--space-3);
    display: flex; flex-direction: column; gap: var(--space-1);
  }
  .problem-card p { font-size: 14px; color: #555; line-height: 1.6; }

  /* ─── Solution ─── */
  .solution { background: var(--color-off-white); }
  .steps { display: grid; grid-template-columns: 1fr 1px 1fr 1px 1fr; gap: 0 var(--space-4); align-items: start; }
  .step-num {
    font-family: 'Space Grotesk', var(--font); font-size: 48px; font-weight: 700;
    color: var(--color-blue); line-height: 1; display: block; margin-bottom: var(--space-1);
  }
  .step h3 { font-size: 18px; margin-top: 0; }
  .step p { font-size: 14px; color: #555; line-height: 1.6; }
  .step-divider { background: #ddd; height: 80px; width: 1px; margin-top: 16px; }

  /* ─── Guardrails ─── */
  .guardrails { background: var(--color-white); }
  .guards-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-2); margin-bottom: var(--space-3); }
  .guard-card { border: 1px solid #e0e0e0; border-top-width: 3px; padding: var(--space-2); }
  .guard-card strong { font-size: 14px; font-weight: var(--weight-bold); display: block; margin-bottom: 6px; }
  .guard-card p { font-size: 13px; color: #555; line-height: 1.5; margin: 0; }
  .guard-deny { border-top-color: var(--color-deny); }
  .guard-warn { border-top-color: var(--color-warn); }
  .guard-blue { border-top-color: var(--color-blue); }
  .guards-note { font-size: 13px; color: #555; margin-bottom: var(--space-2); }
  .guards-note code {
    font-family: 'SF Mono', 'Fira Code', monospace;
    background: #f0f0f0; padding: 1px 4px; font-size: 12px;
  }

  /* ─── Ecosystem ─── */
  .ecosystem { background: var(--color-off-white); }
  .tool-list { font-size: 16px; color: var(--color-near-black); font-weight: var(--weight-bold); letter-spacing: 0.02em; margin-bottom: var(--space-4); }

  /* ─── Quick Start ─── */
  .quick-start { background: var(--color-white); }
  .qs-links { display: flex; gap: var(--space-4); flex-wrap: wrap; }

  /* ─── Analytics ─── */
  .analytics { background: var(--color-near-black); }
  .analytics .section-inner {
    display: flex; flex-direction: column; align-items: center;
    gap: var(--space-3); text-align: center;
  }
  .analytics-label { color: var(--color-meta-gray); }
  .analytics-heading { color: #fff; margin: 0; }
  .analytics-desc {
    font-size: 16px; font-weight: var(--weight-light);
    color: #ccc; max-width: 640px; line-height: 1.7;
  }
  .analytics-features { font-size: 13px; color: var(--color-meta-gray); letter-spacing: 0.03em; }
  .analytics-note { font-size: 12px; color: var(--color-meta-gray); }

  /* ─── Footer CTA ─── */
  .footer-cta { background: var(--color-black); }
  .footer-inner {
    display: flex; flex-direction: column;
    align-items: center; gap: var(--space-3); text-align: center;
  }
  .footer-heading {
    font-family: 'Space Grotesk', var(--font); font-size: 32px; font-weight: 700;
    color: #fff; max-width: 640px; margin: 0;
  }
  .footer-links { display: flex; gap: var(--space-2); align-items: center; }
  .footer-links a {
    font-size: 12px; font-weight: var(--weight-bold); text-transform: uppercase;
    letter-spacing: 0.06em; color: var(--color-meta-gray); text-decoration: none;
    transition: color 150ms;
  }
  .footer-links a:hover { color: #fff; }
  .footer-links a:focus-visible { outline: 2px solid var(--color-blue); outline-offset: 2px; }
  .footer-links span { color: #444; }
  .footer-note { font-size: 11px; color: #444; }

  /* ─── Responsive: tablet ─── */
  @media (max-width: 900px) {
    .hero-inner { grid-template-columns: 1fr; gap: var(--space-4); }
    h1 { font-size: 36px; }
    .cards-3 { grid-template-columns: 1fr; }
    .steps { grid-template-columns: 1fr; }
    .step-divider { display: none; }
    .guards-grid { grid-template-columns: repeat(2, 1fr); }
  }

  /* ─── Responsive: mobile ─── */
  @media (max-width: 480px) {
    h1 { font-size: 28px; }
    h2 { font-size: 24px; }
    .hero-inner { padding: var(--space-6) var(--space-3); }
    .section-inner { padding: var(--space-6) var(--space-3); }
    .guards-grid { grid-template-columns: 1fr; }
    .hero-ctas { flex-direction: column; }
    .footer-heading { font-size: 24px; }
    .qs-links { flex-direction: column; gap: var(--space-2); }
    .steps { gap: var(--space-4) 0; }
  }
</style>
