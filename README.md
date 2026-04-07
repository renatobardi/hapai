# hapai

> Deterministic guardrails for AI coding assistants. Hooks that enforce rules **before execution** — not probabilistic prompts that get ignored.

**hapai** uses Claude Code hooks to intercept tool calls in real-time. When a violation is detected, it's blocked immediately. No markdown instructions to ignore. No promises. Just enforcement.

## The Problem

AI coding tools (Claude Code, Cursor, GitHub Copilot) frequently ignore markdown instructions and safety guidelines. They commit to protected branches, add AI attribution, edit secrets files, and run destructive commands despite explicit rules.

**Why this happens:** LLMs see markdown as suggestions, not requirements. They can't reliably enforce their own rules.

**The solution:** Deterministic enforcement via hooks. You can't ignore a hook — it runs *before* the action, not after.

## Quick Start

```bash
# Clone
git clone https://github.com/renatobardi/hapai.git ~/hapai

# Add to PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Or install per-project
cd your-project && hapai install --project

# Verify
hapai validate
```

## Guardrails (Block Before Execution)

| Guardrail | What it prevents | Config key |
|-----------|-----------------|-----------|
| **Branch Protection** | Commits/pushes to protected branches (main, master, etc.) | `branch_protection.protected` |
| **Commit Hygiene** | Co-Authored-By, AI mentions, "Generated with Claude" | `commit_hygiene.blocked_patterns` |
| **File Protection** | Writes to .env, lockfiles, CI workflow files, and custom protected files | `file_protection.protected` |
| **Destructive Commands** | `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE`, etc. | `command_safety.blocked` |
| **Uncommitted Changes** | AI overwriting your uncommitted work | `uncommitted_changes.enabled` |
| **Blast Radius** | Large commits touching too many files or changing multiple packages | `blast_radius.max_files` |

All guardrails have a `fail_open` setting:
- **`fail_open: false`** — Block execution and show error
- **`fail_open: true`** — Warn but allow execution (for soft constraints)

## Automations (Run After Execution)

| Automation | What it does | Config key |
|-----------|-------------|-----------|
| **Auto-Checkpoint** | Creates granular git snapshots per file edited | `automation.auto_checkpoint` |
| **Auto-Format** | Runs prettier/ruff/black after writes | `automation.auto_format` |
| **Auto-Lint** | Runs ESLint/ruff/pylint, reports issues inline | `automation.auto_lint` |
| **Squash on Stop** | Consolidates checkpoint commits into one clean commit | `automation.auto_checkpoint.squash_on_stop` |

## Observability & Intelligence

| Feature | What it does | Config key |
|---------|-----------|-----------|
| **Audit Log** | Immutable JSONL log of every hook execution | `observability.audit_log` |
| **State Persistence** | Cross-session counters and context | `observability.state` |
| **Production Warnings** | Alerts when prompts mention prod/deploy/release | `intelligence.production_warning` |
| **Session Intelligence** | Loads git status, TODOs, issues at session start | `intelligence.load_context` |
| **Cost Tracker** | Estimates session token cost and warns on thresholds | `intelligence.cost_tracker` |

## CLI Commands

### Installation
```bash
hapai install --global       # Install hooks in ~/.hapai for all projects
hapai install --project      # Install hooks in ./hapai/ for current project only
hapai uninstall [--global]   # Remove hooks (global or current project)
hapai validate               # Verify installation: hooks registered, scripts executable, config OK
```

### Status & Monitoring
```bash
hapai status                 # Show hook registration, audit stats, active guardrails
hapai audit [N]              # Show last N audit entries (default: 20)
```

### Emergency Controls
```bash
hapai kill                   # Disable ALL hooks immediately (for urgent edits)
hapai revive                 # Re-enable hooks after kill
```

### Export to Other Tools
```bash
hapai export --target cursor      # Generate .cursor/rules/ for Cursor
hapai export --target copilot     # Generate .github/copilot-instructions.md
hapai export --target claude      # Generate CLAUDE.md rules
```

## Configuration

Configuration is YAML-based with a three-tier fallback:
1. **Project-level** `./hapai.yaml` (overrides all)
2. **Global** `~/.hapai/hapai.yaml` (applies to all projects)
3. **Defaults** `hapai.defaults.yaml` (shipped with hapai)

### Quick Start: Copy Defaults

```bash
cp hapai.defaults.yaml hapai.yaml
```

Then edit `hapai.yaml` for your project needs.

### Config Structure

```yaml
version: "1.0"
risk_tier: medium  # low | medium | high | critical

# ─── Guardrails (block violations) ───────────────────────
guardrails:
  branch_protection:
    enabled: true
    protected: [main, master]  # List of protected branches
    fail_open: false           # false = block, true = warn only

  commit_hygiene:
    enabled: true
    blocked_patterns:
      - "Co-Authored-By:"
      - "Generated with Claude"
      - "noreply@anthropic.com"
    fail_open: false

  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
      - ".github/workflows/*"
    unprotected:
      - ".env.example"
      - ".env.sample"
    fail_open: false

  command_safety:
    enabled: true
    blocked:
      - "rm -rf"
      - "git push --force"
      - "git reset --hard"
      - "DROP TABLE"
    fail_open: false

  blast_radius:
    enabled: true
    max_files: 10        # warn if commit touches >N files
    max_packages: 2      # warn if touches >N packages (monorepo)
    fail_open: true      # warn but allow (soft constraint)

  uncommitted_changes:
    enabled: true
    fail_open: true      # warn but allow

# ─── Automations (run after execution) ───────────────────
automation:
  auto_checkpoint:
    enabled: false       # Create git snapshots per file
    squash_on_stop: true # Consolidate on session end
    commit_prefix: "checkpoint:"

  auto_format:
    enabled: false
    python: "ruff format {file}"
    javascript: "prettier --write {file}"

  auto_lint:
    enabled: false
    python: "ruff check {file}"
    javascript: "eslint {file}"

# ─── Observability ──────────────────────────────────────
observability:
  audit_log:
    enabled: true
    path: "~/.hapai/audit.jsonl"
    retention_days: 30

  require_tests:
    enabled: false  # Enforce test run before stop
    fail_open: true

  backup_transcripts:
    enabled: true   # Save transcripts before context compaction

  notifications:
    sound_enabled: false

  auto_allow_readonly:
    enabled: false  # Auto-approve Read/Glob/Grep operations

# ─── Intelligence (session awareness) ────────────────────
intelligence:
  production_warning:
    enabled: true
    keywords: ["prod", "production", "deploy", "--prod", "release"]

  load_context:
    enabled: false  # Load git status, TODOs at session start
    scan_todos: true

  cost_tracker:
    enabled: false
    max_tool_calls: 200
    max_cost_cents: 500

# ─── Hook timeouts (seconds) ────────────────────────────
hooks:
  timeouts:
    pre_tool_use: 7
    post_tool_use: 5
    stop: 10
```

### Per-Project Customization

Create `hapai.yaml` in your project root to override global settings. Common customizations:

**Protect project-specific files:**
```yaml
file_protection:
  protected:
    - ".env"
    - "CONSTITUTION.md"
    - "firebase.json"
```

**Strict monorepo rules:**
```yaml
blast_radius:
  max_files: 5
  max_packages: 1
  fail_open: false  # Block instead of warn
```

**Enable automations:**
```yaml
automation:
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"
  auto_lint:
    enabled: true
```

## Architecture & Design

**Technology:**
- **Pure Bash 4+** — No Node, Python, or external services
- **Single external dependency** — `jq` (for JSON I/O, safer than parsing JSON in bash)
- **~2,200 lines of shell code** — 1,550 LOC in hooks + 645 LOC in CLI

**Safety & Reliability:**
- **Graceful failure** — Hooks never crash Claude Code. Internal errors exit 0 (allow execution).
- **Timeouts** — PreToolUse (7s), PostToolUse (5s), Stop (10s). Prevents hanging.
- **No blocking operations** — All hooks run synchronously, no background jobs or subshells.
- **Permission-safe** — Uses `realpath` to resolve symlinks, prevents bypass attempts.

**Modular Design:**
- **One concern per file** — Each guardrail is 50-100 LOC in its own script
- **Shared library** — `hooks/_lib.sh` provides config loading, JSON I/O, audit logging
- **Conditional execution** — Hooks check tool name and only run if relevant

**Observability:**
- **Immutable audit log** — `~/.hapai/audit.jsonl` (JSONL format, append-only)
- **Per-hook counters** — `~/.hapai/state/{hook-name}.count` for cross-session tracking
- **Structured logging** — JSON audit entries include timestamp, hook name, result, reason, project

**Portability:**
- **Global + Project scope** — Hooks can be installed globally or per-project
- **Export targets** — Generate rules for Cursor (`.cursor/rules/`) and GitHub Copilot (`.github/copilot-instructions.md`)
- **Idempotent installation** — Running `hapai install` twice doesn't duplicate entries

## How It Works

hapai uses Claude Code's hook system to intercept tool calls at three critical points:

1. **PreToolUse** — Before execution (guard scripts block violations)
2. **PostToolUse** — After execution (automations like format/lint/checkpoint run)
3. **Stop** — Session completion (squash checkpoints, require tests, estimate cost)

```
User prompt
    ↓
Claude Code tool call
    ↓
PreToolUse hook → hapai guard script
    ├─ Violation detected? → exit 2 (DENY) + log audit entry
    └─ Clean? → exit 0 (ALLOW)
    ↓
[Tool executes or is blocked]
    ↓
PostToolUse hook → hapai automation script
    └─ Format, lint, checkpoint, audit log
    ↓
[Continue or Stop]
    ↓
Stop hook → hapai cleanup script
    └─ Squash checkpoints, verify tests, estimate cost
```

All hooks:
- Run with **7-10 second timeouts** (never hang Claude Code)
- Exit gracefully on internal errors (exit 0, never crash the host tool)
- Log actions to `~/.hapai/audit.jsonl` (append-only, immutable)
- Read config from `hapai.yaml` (project-local first, then global)

## Directory Structure

```
~/.hapai/                          # Global hapai directory
├── hooks/                         # Hook scripts (11 files, ~1550 LOC)
│   ├── _lib.sh                    # Shared library (config, JSON I/O, audit)
│   ├── pre-tool-use/              # Guardrails (block violations)
│   │   ├── guard-branch.sh
│   │   ├── guard-commit-msg.sh
│   │   ├── guard-destructive.sh
│   │   ├── guard-files.sh
│   │   ├── guard-blast-radius.sh
│   │   └── guard-uncommitted.sh
│   ├── post-tool-use/             # Automations (run after execution)
│   │   ├── auto-checkpoint.sh
│   │   ├── auto-format.sh
│   │   ├── auto-lint.sh
│   │   └── audit-trail.sh
│   ├── stop/                      # Session-end hooks
│   │   ├── squash-checkpoints.sh
│   │   ├── require-tests.sh
│   │   └── cost-tracker.sh
│   └── [other hooks for observability, notifications, etc.]
├── hapai.yaml                     # Global config (same structure as defaults)
├── audit.jsonl                    # Immutable audit log (JSONL format)
└── state/                         # Cross-session state
    ├── guard-branch.count
    ├── guard-files.count
    └── [other guardrail counters]

project-root/
├── hapai.yaml                     # Project-specific config (overrides global)
├── .claude/settings.json          # Hooks registered here (project scope)
└── CLAUDE.md                      # Rules injected with <!-- hapai:start/end -->
```

## Testing & Development

### Run the Test Suite

```bash
bash tests/run-tests.sh
```

The test suite is pure bash assertions (no test framework dependency). Tests include:
- Unit tests for guard scripts (violation detection, edge cases)
- Integration tests (config loading, JSON parsing, audit logging)
- End-to-end tests (hook registration, CLI commands)

Coverage: ~200 assertions across 11 hook modules.

## Troubleshooting

**Q: Hooks are running but not blocking. Why?**
- Check `hapai status` to verify hooks are registered
- Check `fail_open: false` in `hapai.yaml` (default is to block)
- Run `hapai audit` to see what the hook decided
- Verify config is in the right place: project `hapai.yaml` overrides global

**Q: Can I disable a specific guardrail?**
- Edit `hapai.yaml` and set `enabled: false` for that guardrail
- Or run `hapai kill` to disable all hooks temporarily

**Q: The hook timed out. What happened?**
- Hooks have timeouts: PreToolUse (7s), PostToolUse (5s), Stop (10s)
- If a hook times out, it's killed and execution continues (fail-open behavior)
- This prevents Claude Code from hanging

**Q: Can I add custom guardrails?**
- Yes. Create a new script in `~/.hapai/hooks/pre-tool-use/my-custom-guard.sh`
- Source `_lib.sh` to access config/audit utilities
- Exit 0 (allow) or 2 (deny)
- Register in `~/.claude/settings.json`

**Q: How do I see what hooks are doing?**
- `hapai audit` — Shows recent hook executions
- `hapai status` — Shows registration and stats
- Manual: `tail -f ~/.hapai/audit.jsonl | jq` — Stream audit log as JSON

## Requirements

- **bash 4+** (check with `bash --version`)
- **jq** (JSON parser; install via `brew install jq`, `apt install jq`, etc.)
- **git** (for branch detection and git commands)

## License

MIT — See LICENSE file for details.

## Contributing

Contributions welcome. Please:
1. Add tests for new guardrails (see `tests/run-tests.sh` for format)
2. Follow bash conventions: `set -euo pipefail`, shellcheck compliance
3. Keep hooks modular: one concern per file, 50-100 LOC
4. Document config keys in `hapai.defaults.yaml` with comments

## Support & Issues

- **Bugs:** [GitHub Issues](https://github.com/renatobardi/hapai/issues)
- **Docs:** See [USAGE.md](USAGE.md) (Portuguese) for detailed examples
- **CLAUDE.md:** See [CLAUDE.md](CLAUDE.md) for developer guidance on codebase architecture
