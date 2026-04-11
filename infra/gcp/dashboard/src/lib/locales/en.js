export default {
  header: {
    subtitle: 'Guardrails Analytics',
    nav: { dashboard: 'Dashboard', docs: 'How it works' },
    auth: { signIn: 'Sign in with GitHub', signOut: 'Sign out', signingIn: 'Signing in…', signInError: 'Sign-in failed. Please try again.' }
  },
  app: { initializing: 'Initializing…' },
  landing: {
    hero: {
      headline: 'Your AI just pushed to main. Again.',
      sub: 'hapai is a deterministic guardrails system for AI coding assistants. Shell-based hooks that block dangerous actions before they execute — not markdown rules the AI ignores.',
      cta: 'Get Started',
      github: 'View on GitHub'
    },
    problem: {
      label: 'The Problem',
      heading: 'AI coding tools ignore your rules',
      cards: [
        { title: 'Commits to protected branches', desc: 'You wrote "never push to main" in CLAUDE.md. The AI read it, acknowledged it, and pushed to main anyway. Markdown is a suggestion, not a constraint.' },
        { title: 'Destructive commands in production', desc: 'rm -rf, git push --force, DROP TABLE — AI assistants will run these if the context suggests it. One bad inference, permanent damage.' },
        { title: 'Silent edits to sensitive files', desc: "Your .env got committed. Your lockfile got rewritten. Your CI workflow was modified. You didn't notice until the build broke — or worse, until it didn't." }
      ]
    },
    solution: {
      label: 'The Solution',
      heading: 'Hooks, not prompts. Deterministic, not probabilistic.',
      steps: [
        { title: 'Install in 30 seconds', desc: 'Clone the repo, add to PATH, run hapai install --global. Three commands. No SDK, no server, no dependencies beyond bash and jq.' },
        { title: 'Hooks intercept every action', desc: "Every time your AI assistant tries to run a command, edit a file, or make a commit — hapai's shell hooks evaluate it against your rules before it executes." },
        { title: 'Violations are blocked, not logged', desc: 'When a rule is violated, the action is denied. The AI gets a clear error message and instructions on how to proceed correctly. No damage done.' }
      ]
    },
    guardrails: {
      label: 'Guardrails',
      heading: '11 deterministic guards. Every one configurable.',
      note: 'Every guard supports fail_open mode — set to true for soft warnings, false for hard blocks.',
      link: 'See full configuration →',
      guards: {
        branchProtection: 'Blocks commits and pushes to main, master, or any protected branch.',
        branchTaxonomy: 'Enforces naming conventions: feat/, fix/, chore/, docs/, hotfix/.',
        branchRules: 'Validates branch descriptions and origin tracking.',
        commitHygiene: 'Strips AI attribution: Co-Authored-By, "Generated with Claude".',
        fileProtection: 'Prevents writes to .env, lockfiles, CI workflows, and any pattern you define.',
        destructiveCommands: 'Blocks rm -rf, git push --force, DROP TABLE, and configurable patterns.',
        blastRadius: 'Warns when a commit touches too many files or packages. Monorepo-aware.',
        uncommittedChanges: 'Prevents the AI from overwriting your uncommitted work.',
        prReview: 'Background code review on every PR. Optional auto-fix before blocking.',
        gitWorkflow: 'Enforces trunk-based or GitFlow model across the team.',
        flowDispatcher: 'Sequential hook chains with conditional gate logic for complex workflows.'
      }
    },
    ecosystem: {
      label: 'Ecosystem',
      heading: 'One config. Every AI coding tool.'
    },
    quickStart: {
      label: 'Quick Start',
      heading: "Three commands. You're protected.",
      links: { config: 'Want to configure guardrails?', overrides: 'Need project-level overrides?' }
    },
    analytics: {
      label: 'Analytics',
      heading: 'See what your AI is doing.',
      desc: 'hapai logs every action — denials, warnings, and allows — to an append-only audit trail. Sync to BigQuery for enterprise analytics, or use the built-in dashboard to visualize guardrail activity across all your projects.',
      features: '30-day timeline · Top blocking hooks · Tool distribution · Per-project breakdown · Deny rate trends',
      cta: 'Sign in with GitHub',
      signingIn: 'Signing in…',
      signInError: 'Sign in failed. Try again.',
      note: 'Dashboard requires GitHub authentication. Your audit data stays yours.'
    },
    footer: {
      heading: 'Stop hoping the AI will follow the rules. Enforce them.',
      cta: 'Get Started',
      links: { github: 'GitHub', docs: 'Documentation', changelog: 'Changelog' },
      note: 'hapai v1.5.1 · Pure bash. Zero dependencies. Deterministic safety.'
    }
  },
  docs: {
    nav: {
      groups: { gettingStarted: 'Getting Started', configuration: 'Configuration', reference: 'Reference', cloud: 'Cloud', help: 'Help' },
      whatIs: 'What is hapai',
      quickStart: 'Quick Start',
      guardrails: 'Guardrails',
      configuration: 'Configuration',
      automations: 'Automations',
      cliCommands: 'CLI Commands',
      analytics: 'Analytics',
      cloudLogging: 'Cloud Logging',
      export: 'Export',
      faq: 'FAQ'
    },
    sections: {
      whatIs: {
        heading: 'What is hapai',
        p1: 'hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations before execution — not probabilistic prompts that get ignored.',
        p2: 'Why this matters: AI coding tools frequently ignore markdown instructions. They commit to protected branches, edit secrets files, run destructive commands, and add AI attribution despite explicit rules. LLMs see markdown as suggestions, not requirements.',
        p3: 'The solution: Deterministic enforcement via hooks running before the action, not after.'
      },
      quickStart: { heading: 'Quick Start' },
      guardrails: {
        heading: 'Guardrails',
        intro: 'Guardrails block violations before execution. All support fail_open:',
        guards: [
          'Branch Protection — Commits/pushes to protected branches (main, master)',
          'Branch Taxonomy — Enforces naming conventions (feat/, fix/, chore/, etc.)',
          'Commit Hygiene — Blocks Co-Authored-By, AI mentions, "Generated with Claude"',
          'File Protection — Prevents writes to .env, lockfiles, CI workflow files',
          'Destructive Commands — Blocks rm -rf, git push --force, DROP TABLE, etc.',
          'Blast Radius — Warns on large commits touching too many files',
          'Uncommitted Changes — Prevents overwriting your uncommitted work',
          'PR Review — Background code review on all PRs (optional)',
          'Git Workflow — Trunk-based or GitFlow enforcement'
        ],
        failOpenTitle: 'fail_open modes:',
        failOpenModes: [
          'fail_open: false — Block execution, show error',
          'fail_open: true — Warn but allow (soft constraints)'
        ]
      },
      configuration: {
        heading: 'Configuration',
        intro: 'YAML-based with three-tier fallback:',
        tiers: [
          'Project ./hapai.yaml (overrides all)',
          'Global ~/.hapai/hapai.yaml',
          'Defaults hapai.defaults.yaml'
        ]
      },
      automations: {
        heading: 'Automations',
        intro: 'Automations run after execution. Enable in hapai.yaml:'
      },
      cliCommands: {
        heading: 'CLI Commands',
        installation: 'Installation:',
        monitoring: 'Monitoring:',
        emergency: 'Emergency:',
        export: 'Export:'
      },
      analytics: {
        heading: 'Analytics Dashboard',
        intro: 'This dashboard displays real-time guardrail events from your audit logs:',
        features: [
          'Timeline — Daily denial/warning counts (30-day rolling window)',
          'Top Blocking Hooks — Which guardrails are most active',
          'Recent Events — Live feed of denials and warnings',
          'Tool Distribution — Which tools trigger guards most',
          'Project Breakdown — Per-project statistics',
          'Deny Rate Trend — Historical analysis'
        ],
        setupTitle: 'Setup:',
        setup: [
          'Create Firebase project with GitHub OAuth',
          'Set GitHub Actions secrets (VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID)',
          'Push to main → GitHub Actions builds and deploys to GitHub Pages',
          'Dashboard live at: https://owner.github.io/repo/'
        ]
      },
      cloudLogging: {
        heading: 'Cloud Logging (Optional)',
        p1: 'Sync audit logs to GCP for enterprise analytics and compliance.',
        archTitle: 'Architecture:',
        enableTitle: 'Enable in hapai.yaml:',
        syncTitle: 'Sync:',
        autoSyncTitle: 'Auto-sync:',
        autoSyncColMethod: 'Tool',
        autoSyncColWhen: 'When',
        autoSyncColHow: 'How',
        autoSyncSessionEnd: 'Session end',
        autoSyncPostCommit: 'After each commit'
      },
      export: {
        heading: 'Export to Other Tools',
        p1: 'hapai exports guardrails to 6 different AI coding tools:',
        cols: { tool: 'Tool', file: 'File', command: 'Command' },
        exportAll: 'Export all tools at once:',
        gitHooksNote: 'Auto-sync audit log after every commit — works with any tool that uses git:'
      },
      faq: {
        heading: 'FAQ',
        questions: [
          { q: 'Do hooks affect Claude Code performance?', a: 'Minimal. Each hook runs in <100ms. PreToolUse has 7s timeout, PostToolUse has 5s timeout.' },
          { q: 'How do I temporarily disable a guardrail?', a: 'Edit hapai.yaml and set enabled: false for that guardrail, or use hapai kill to disable all hooks.' },
          { q: 'Can I create custom guardrails?', a: 'Yes. Create a script in ~/.hapai/hooks/pre-tool-use/my-guard.sh and register it in ~/.claude/settings.json.' },
          { q: 'Where are audit logs stored?', a: 'Local: ~/.hapai/audit.jsonl (append-only). Cloud: BigQuery (if GCP sync enabled).' },
          { q: 'How do I see what hooks are doing?', a: 'Use hapai audit to see recent entries, or tail -f ~/.hapai/audit.jsonl to stream live.' }
        ]
      },
      footer: 'For detailed setup guides, see hapai on GitHub.'
    }
  },
  dashboard: {
    loading: 'Fetching analytics…',
    error: 'Error',
    retry: 'Retry',
    denials: 'Actions Blocked',
    warnings: 'Warnings Issued'
  },
  charts: {
    timeline: 'Daily Activity',
    hooks: 'Top Guards',
    hotspots: { title: 'Hotspots', byTool: 'By Tool', byProject: 'By Project' },
    labels: { denials: 'Denials', warnings: 'Warnings', denialsPerDay: 'Denials per day' }
  },
  table: {
    title: 'Recent Events',
    empty: 'All clear. When hapai blocks or warns an action, it will show up here.',
    noMatches: 'No events match these filters. Try broadening your selection.',
    filterAll: 'All types',
    filterHook: 'All hooks',
    filterTool: 'All tools',
    clearFilters: 'Clear filters',
    viewAll: 'View all events',
    loadMore: 'Load more from server',
    cols: { time: 'Time', type: 'Type', hook: 'Hook', tool: 'Tool', reason: 'Reason' }
  },
  statCard: { period: 'Last 30 days', period7d: 'Last 7 days', period14d: 'Last 14 days', allowRate: 'Allow Rate', denyRate: 'Deny Rate' },
  loading: { default: 'Loading…' },
  common: { justNow: 'just now', minutesAgo: 'm ago', hoursAgo: 'h ago' },
  drilldown: {
    close: '×',
    denials: 'denials',
    warnings: 'warnings',
    triggeredByTool: 'Triggered by tool',
    triggeredByGuard: 'Triggered by guard',
    recentEvents: 'Recent Events',
    empty: 'No events in this period.',
    viewEvent: 'View',
    loading: 'Loading…',
    activity: 'Activity',
    denyRate: 'deny rate'
  },
  detail: {
    title: 'Event Detail',
    close: 'Close',
    prev: '← Prev',
    next: 'Next →',
    guard: 'Guard',
    tool: 'Tool',
    project: 'Project',
    reason: 'Reason',
    time: 'Time',
    of: 'of'
  }
}
