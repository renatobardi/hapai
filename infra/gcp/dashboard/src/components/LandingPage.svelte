<script>
  import { signIn } from '../lib/firebase.js'
  import { navigate } from '../stores/route.js'
  import { t } from '../stores/i18n.js'
  import Button from './Button.svelte'

  let signingIn = $state(false)
  let signInError = $state('')

  async function handleSignIn() {
    signingIn = true; signInError = ''
    try { await signIn() } catch(e) {
      if (e.code !== 'auth/popup-closed-by-user') signInError = $t('landing.analytics.signInError')
    } finally { signingIn = false }
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
    { name: 'Branch Protection',    color: 'deny', key: 'branchProtection' },
    { name: 'Branch Taxonomy',      color: 'warn', key: 'branchTaxonomy' },
    { name: 'Branch Rules',         color: 'warn', key: 'branchRules' },
    { name: 'Commit Hygiene',       color: 'deny', key: 'commitHygiene' },
    { name: 'File Protection',      color: 'deny', key: 'fileProtection' },
    { name: 'Destructive Commands', color: 'deny', key: 'destructiveCommands' },
    { name: 'Blast Radius',         color: 'warn', key: 'blastRadius' },
    { name: 'Uncommitted Changes',  color: 'warn', key: 'uncommittedChanges' },
    { name: 'PR Review',            color: 'deny', key: 'prReview' },
    { name: 'Git Workflow',         color: 'warn', key: 'gitWorkflow' },
    { name: 'Flow Dispatcher',      color: 'blue', key: 'flowDispatcher' },
  ]
</script>

<!-- ─── Hero ─── -->
<section class="hero" use:fadeIn>
  <div class="hero-inner">
    <div class="hero-text">
      <h1>{$t('landing.hero.headline')}</h1>
      <p class="hero-sub">{$t('landing.hero.sub')}</p>
      <div class="hero-ctas">
        <Button size="lg" onclick={scrollToQuickStart}>{$t('landing.hero.cta')}</Button>
        <a class="btn-ghost" href="https://github.com/renatobardi/hapai" target="_blank" rel="noopener">{$t('landing.hero.github')}</a>
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
    <p class="section-label">{$t('landing.problem.label')}</p>
    <h2>{$t('landing.problem.heading')}</h2>
    <div class="cards-3">
      {#each $t('landing.problem.cards') as card, i}
        <div class="problem-card">
          <span class="badge {i === 2 ? 'badge-warn' : 'badge-deny'}">{i === 2 ? 'WARN' : 'DENY'}</span>
          <h3>{card.title}</h3>
          <p>{card.desc}</p>
        </div>
      {/each}
    </div>
  </div>
</section>

<!-- ─── Solution ─── -->
<section class="solution" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">{$t('landing.solution.label')}</p>
    <h2>{$t('landing.solution.heading')}</h2>
    <div class="steps">
      {#each $t('landing.solution.steps') as step, i}
        {#if i > 0}<div class="step-divider" aria-hidden="true"></div>{/if}
        <div class="step">
          <span class="step-num">0{i + 1}</span>
          <h3>{step.title}</h3>
          <p>{step.desc}</p>
        </div>
      {/each}
    </div>
  </div>
</section>

<!-- ─── Guardrails ─── -->
<section class="guardrails" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">{$t('landing.guardrails.label')}</p>
    <h2>{$t('landing.guardrails.heading')}</h2>
    <div class="guards-grid">
      {#each guards as g}
        <div class="guard-card guard-{g.color}">
          <strong>{g.name}</strong>
          <p>{$t(`landing.guardrails.guards.${g.key}`)}</p>
        </div>
      {/each}
    </div>
    <p class="guards-note">{$t('landing.guardrails.note')}</p>
    <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>{$t('landing.guardrails.link')}</a>
  </div>
</section>

<!-- ─── Ecosystem ─── -->
<section class="ecosystem" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">{$t('landing.ecosystem.label')}</p>
    <h2>{$t('landing.ecosystem.heading')}</h2>
    <p class="tool-list">Claude Code · Cursor · GitHub Copilot · Devin · Windsurf · Trae · Antigravity</p>
    <pre class="code-block"># Export guardrails to all tools at once
hapai export --all

# Or target a specific tool
hapai export --target cursor
hapai export --target copilot

# Auto-sync audit log after every commit (any tool)
hapai install --git-hooks</pre>
  </div>
</section>

<!-- ─── Quick Start ─── -->
<section class="quick-start" id="quick-start" use:fadeIn>
  <div class="section-inner">
    <p class="section-label">{$t('landing.quickStart.label')}</p>
    <h2>{$t('landing.quickStart.heading')}</h2>
    <pre class="code-block"># Clone
git clone https://github.com/renatobardi/hapai.git ~/hapai

# Add to PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Verify everything works
hapai validate</pre>
    <div class="qs-links">
      <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>{$t('landing.quickStart.links.config')}</a>
      <a class="text-link" href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>{$t('landing.quickStart.links.overrides')}</a>
    </div>
  </div>
</section>

<!-- ─── Analytics Preview ─── -->
<section class="analytics" use:fadeIn>
  <div class="section-inner">
    <p class="section-label analytics-label">{$t('landing.analytics.label')}</p>
    <h2 class="analytics-heading">{$t('landing.analytics.heading')}</h2>
    <p class="analytics-desc">{$t('landing.analytics.desc')}</p>
    <p class="analytics-features">{$t('landing.analytics.features')}</p>
    <Button size="lg" onclick={handleSignIn} disabled={signingIn}>
      {signingIn ? $t('landing.analytics.signingIn') : $t('landing.analytics.cta')}
    </Button>
    {#if signInError}<p class="signin-error">{signInError}</p>{/if}
    <p class="analytics-note">{$t('landing.analytics.note')}</p>
  </div>
</section>

<!-- ─── Footer CTA ─── -->
<section class="footer-cta" use:fadeIn>
  <div class="section-inner footer-inner">
    <h2 class="footer-heading">{$t('landing.footer.heading')}</h2>
    <Button size="lg" onclick={scrollToQuickStart}>{$t('landing.footer.cta')}</Button>
    <nav class="footer-links" aria-label="Footer links">
      <a href="https://github.com/renatobardi/hapai" target="_blank" rel="noopener">{$t('landing.footer.links.github')}</a>
      <span aria-hidden="true">·</span>
      <a href="#/docs" onclick={(e) => { e.preventDefault(); navigate('#/docs') }}>{$t('landing.footer.links.docs')}</a>
      <span aria-hidden="true">·</span>
      <a href="https://github.com/renatobardi/hapai/blob/main/CHANGELOG.md" target="_blank" rel="noopener">{$t('landing.footer.links.changelog')}</a>
    </nav>
    <p class="footer-note">{$t('landing.footer.note')}</p>
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
    background: var(--color-near-black); color: var(--color-text-on-dark);
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
    color: var(--color-text-on-dark); margin: 0 0 var(--space-4); line-height: 1.6;
  }
  .hero-ctas { display: flex; gap: var(--space-2); flex-wrap: wrap; }

  .terminal { background: var(--surface-terminal); border: 1px solid var(--color-border-dark); }
  .terminal-bar { background: var(--surface-terminal-bar); padding: 10px 14px; display: flex; gap: 6px; align-items: center; }
  .dot { width: 10px; height: 10px; background: var(--color-text-on-dark-subtle); display: block; }
  .terminal-body {
    margin: 0; padding: var(--space-3);
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 13px; line-height: 1.7; color: var(--color-text-on-dark-muted);
    white-space: pre; overflow-x: auto;
  }
  .t-prompt { color: var(--color-meta-gray); }
  .t-deny { color: var(--color-deny); font-weight: var(--weight-bold); }
  .t-guard { color: var(--color-meta-gray); }

  /* ─── Problem ─── */
  .problem { background: var(--color-white); }
  .cards-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-3); }
  .problem-card {
    border: 1px solid var(--color-border-medium); padding: var(--space-3);
    display: flex; flex-direction: column; gap: var(--space-1);
  }
  .problem-card p { font-size: 14px; color: var(--color-text-muted); line-height: 1.6; }

  /* ─── Solution ─── */
  .solution { background: var(--color-off-white); }
  .steps { display: grid; grid-template-columns: 1fr 1px 1fr 1px 1fr; gap: 0 var(--space-4); align-items: start; }
  .step-num {
    font-family: 'Space Grotesk', var(--font); font-size: 48px; font-weight: 700;
    color: var(--color-blue); line-height: 1; display: block; margin-bottom: var(--space-1);
  }
  .step h3 { font-size: 18px; margin-top: 0; }
  .step p { font-size: 14px; color: var(--color-text-muted); line-height: 1.6; }
  .step-divider { background: var(--color-border-medium); height: 80px; width: 1px; margin-top: 16px; }

  /* ─── Guardrails ─── */
  .guardrails { background: var(--color-white); }
  .guards-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-2); margin-bottom: var(--space-3); }
  .guard-card { border: 1px solid var(--color-border-medium); border-top-width: 3px; padding: var(--space-2); }
  .guard-card strong { font-size: 14px; font-weight: var(--weight-bold); display: block; margin-bottom: 6px; }
  .guard-card p { font-size: 13px; color: var(--color-text-muted); line-height: 1.5; margin: 0; }
  .guard-deny { border-top-color: var(--color-deny); }
  .guard-warn { border-top-color: var(--color-warn); }
  .guard-blue { border-top-color: var(--color-blue); }
  .guards-note { font-size: 13px; color: var(--color-text-muted); margin-bottom: var(--space-2); }

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
    color: var(--color-text-on-dark-muted); max-width: 640px; line-height: 1.7;
  }
  .analytics-features { font-size: 13px; color: var(--color-meta-gray); letter-spacing: 0.03em; }
  .analytics-note { font-size: 12px; color: var(--color-meta-gray); }
  .signin-error { font-size: 12px; color: var(--color-deny); font-weight: var(--weight-bold); }

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
  .footer-links span { color: var(--color-text-on-dark-subtle); }
  .footer-note { font-size: 11px; color: var(--color-text-on-dark-subtle); }

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
