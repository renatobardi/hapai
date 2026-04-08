#!/usr/bin/env bash
# Exports hapai guardrails as Windsurf rules (.windsurf/rules/hapai.md)
# Format: Markdown with trigger frontmatter (Wave 8+)
set -euo pipefail

HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_BODY="$(cat "$HAPAI_ROOT/templates/guardrails-rules.md")"

mkdir -p .windsurf/rules

cat > .windsurf/rules/hapai.md << RULES
---
trigger: always_on
description: "Hapai guardrails — deterministic safety rules for AI coding"
---

# Hapai Guardrails

$RULES_BODY
RULES

echo ".windsurf/rules/hapai.md"
