#!/usr/bin/env bash
# Exports hapai guardrails as Trae rules (.trae/rules/hapai.md)
# Format: Markdown with alwaysApply frontmatter
set -euo pipefail

HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_BODY="$(cat "$HAPAI_ROOT/templates/guardrails-rules.md")"

mkdir -p .trae/rules

cat > .trae/rules/hapai.md << RULES
---
alwaysApply: true
---

# Hapai Guardrails

$RULES_BODY
RULES

echo ".trae/rules/hapai.md"
