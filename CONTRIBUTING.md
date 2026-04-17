# Contributing to hapai

Thank you for your interest in contributing to hapai! This document outlines the process for submitting changes.

## Getting Started

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/hapai.git
cd hapai
```

### 2. Install for Development

```bash
# For local development with hooks installed to ~/.hapai
HAPAI_DEV=1 bash install.sh

# Verify installation
hapai validate
```

### 3. Run Tests

```bash
# Run all tests (bash assertions, no framework)
bash tests/run-tests.sh

# Test a specific hook
bash tests/run-tests.sh 2>&1 | grep -A 10 "guard-branch"

# Test individual hook in isolation
HOOK_INPUT='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
echo "$HOOK_INPUT" | bash hooks/pre-tool-use/guard-branch.sh
```

## Contributing a New Guardrail

### Step 1: Create the Hook Script

1. Create `hooks/pre-tool-use/guard-{name}.sh` (or appropriate event type)
2. Source `hooks/_lib.sh` for utilities
3. Read JSON input via `read_input()` and `get_field()`
4. Call `allow()`, `warn()`, or `deny()` with optional context
5. Exit 0 to allow, 2 to deny

### Step 2: Register the Hook

1. Update `templates/settings.hooks.json` under the appropriate hook event type
2. Specify the `if:` condition to match relevant tools
3. Set `gate: block` for hard deny, `gate: warn` for soft warn

### Step 3: Add Configuration

1. Add a config key to `hapai.defaults.yaml` under `guardrails.{name}`
2. Document the key in CLAUDE.md

### Step 4: Write Tests

1. Add test cases to `tests/run-tests.sh`
2. Test both allow and deny cases
3. Test with different config values (`fail_open: true/false`)
4. Use isolated `HAPAI_HOME` for each test group

### Step 5: Document

1. Update README.md guardrails table
2. Add description to CLAUDE.md Architecture section
3. Update CHANGELOG.md with new feature

## Commit Convention

Use conventional commits for clear commit messages:

- `feat(hook)`: New feature or guardrail
- `fix(hook)`: Bug fix in existing guardrail
- `docs(readme)`: Documentation updates
- `chore(deps)`: Dependency or tooling changes
- `refactor(lib)`: Code restructuring without behavior change
- `test(guard-branch)`: Test additions or fixes
- `perf(audit)`: Performance improvements

**Example:**
```bash
git commit -m "feat(guard): add new SSRF detector for guard-ssrf.sh"
```

## Branch Naming

Create feature branches with prefixes:

- `feat/my-feature` — New guardrail or feature
- `fix/my-bug` — Bug fix
- `docs/my-docs` — Documentation only
- `chore/my-task` — Maintenance or tooling
- `refactor/my-code` — Code restructuring

## Pull Request Checklist

Before submitting a PR:

- [ ] All tests pass: `bash tests/run-tests.sh`
- [ ] No new external dependencies (hapai uses only `jq`)
- [ ] `hapai.defaults.yaml` updated (if new config key)
- [ ] CHANGELOG.md updated with your changes
- [ ] CLAUDE.md or README.md updated (if user-facing)
- [ ] Commit messages follow convention

## Philosophy

hapai follows these principles:

- **Pure Bash** — All hooks are portable bash scripts
- **Zero external dependencies** — Only `jq` is required (beyond bash, git, curl)
- **Fail-open on internal errors** — Hooks never crash Claude Code; all errors exit 0
- **Deterministic enforcement** — Rules block violations before execution, not after
- **Minimal overhead** — Hooks run in < 1 second per tool invocation

## Testing Your Changes

### Local Validation

```bash
# Validate your hook syntax
bash -n hooks/pre-tool-use/guard-myguard.sh

# Test with isolated state
export HAPAI_HOME="$(mktemp -d)"
mkdir -p "$HAPAI_HOME/state"
cp hapai.defaults.yaml "$HAPAI_HOME/hapai.yaml"

# Run your hook test
bash tests/run-tests.sh 2>&1 | grep "guard-myguard"
```

### CI/CD

Your PR will automatically run:

- `bash tests/run-tests.sh` on Ubuntu and macOS
- Bash syntax checks
- JSON validation for templates/settings.hooks.json

## Questions?

- Open an issue for bugs or feature requests
- Check existing issues for similar topics
- Review CLAUDE.md for architecture details
