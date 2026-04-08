#!/usr/bin/env bash
# Exports hapai guardrails as Cursor rules (.cursor/rules/hapai.mdc)
# Format: MDC (Markdown Content) with frontmatter
set -euo pipefail

HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_BODY="$(cat "$HAPAI_ROOT/templates/guardrails-rules.md")"

mkdir -p .cursor/rules

cat > .cursor/rules/hapai.mdc << RULES
---
description: Hapai guardrails — deterministic safety rules for AI coding
globs:
alwaysApply: true
---

# Hapai Guardrails

$RULES_BODY
RULES

echo ".cursor/rules/hapai.mdc"
