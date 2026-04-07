# hapai

Deterministic guardrails for AI coding assistants. Hooks that enforce rules before execution — not probabilistic prompts that get ignored.

## The Problem

AI coding tools (Claude Code, Cursor, Copilot) frequently ignore instructions in CLAUDE.md, spec files, and markdown rules. They commit to main, add AI attribution, edit protected files, and run destructive commands despite being told not to.

**hapai** solves this with deterministic enforcement: shell-based hooks that intercept tool calls and block violations before they happen.

## Quick Start

```bash
# Clone
git clone https://github.com/renatobardi/hapai.git ~/Projetos/hapai

# Add to PATH
ln -sf ~/Projetos/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Or install per-project
cd your-project && hapai install --project

# Verify
hapai validate
```

## What Gets Blocked

| Guardrail | What it prevents |
|-----------|-----------------|
| **Branch Protection** | Commits/pushes to main, master, or other protected branches |
| **Commit Hygiene** | Co-Authored-By headers, AI mentions, "Generated with Claude" |
| **Destructive Commands** | `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE` |
| **File Protection** | Writes to `.env`, lockfiles, CI workflow files |
| **Uncommitted Changes** | AI overwriting your manual work that hasn't been committed |
| **Blast Radius** | Large commits touching too many files or packages |

## What Gets Automated

| Automation | What it does |
|-----------|-------------|
| **Auto-Format** | Runs prettier/ruff after every file write |
| **Auto-Lint** | Runs ESLint/ruff check after writes, reports issues |
| **Auto-Checkpoint** | Creates precise git snapshots per file (not `git add .`) |
| **Squash on Stop** | Consolidates checkpoint commits into one clean commit |

## CLI Commands

```bash
hapai install --global       # Install hooks for all projects
hapai install --project      # Install hooks for current project
hapai uninstall [--global]   # Remove hooks
hapai validate               # Verify installation integrity
hapai status                 # Show active hooks, audit stats
hapai audit [N]              # Show last N audit log entries
hapai kill                   # Emergency kill switch
hapai revive                 # Restore after kill
hapai export --target cursor # Export guardrails for Cursor
hapai export --target copilot # Export for GitHub Copilot
```

## Configuration

Copy `hapai.defaults.yaml` as `hapai.yaml` in your project root to customize:

```yaml
version: "1.0"
risk_tier: medium

guardrails:
  branch_protection:
    enabled: true
    protected: [main, master, develop]
    fail_open: false

  commit_hygiene:
    enabled: true
    blocked_patterns:
      - "Co-Authored-By:"
      - "Generated with Claude"

  file_protection:
    enabled: true
    protected: [".env", "*.lock", ".github/workflows/*"]
    unprotected: [".env.example"]

  blast_radius:
    enabled: true
    max_files: 10
    max_packages: 2
    fail_open: true  # warn but don't block

automation:
  auto_checkpoint:
    enabled: true
    squash_on_stop: true
```

## Architecture

- **Pure bash** — no Node, Python, or external services
- **Single dependency** — `jq` (for JSON parsing)
- **Graceful failure** — hooks never crash the host tool
- **Modular** — each guardrail is an independent script
- **Audit trail** — every hook execution logged to `~/.hapai/audit.jsonl`
- **State persistence** — counters and context survive across sessions
- **Multi-tool export** — same guardrails for Claude Code, Cursor, and Copilot

## How It Works

hapai uses Claude Code hooks (PreToolUse, PostToolUse, Stop) to intercept tool calls. When a hook detects a violation, it returns a JSON `deny` response that blocks the action before execution. This is deterministic — unlike markdown instructions, hooks cannot be ignored.

```
User prompt → Claude Code → PreToolUse hook → hapai guard script
                                                    ↓
                                              Violation? → Block + audit log
                                              Clean?     → Allow
```

## Directory Structure

```
~/.hapai/
├── hooks/          # Hook scripts (global install)
├── hapai.yaml      # Global config
├── audit.jsonl     # Immutable audit log
└── state/          # Cross-session state (counters, etc.)
```

## Running Tests

```bash
cd ~/Projetos/hapai
bash tests/run-tests.sh
```

## Requirements

- bash 4+
- jq
- git

## License

MIT
