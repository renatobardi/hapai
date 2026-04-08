#!/usr/bin/env bash
# Exports hapai guardrails as GEMINI.md (used by Antigravity/Google)
# Also updates AGENTS.md via the universal exporter for cross-tool compat
set -euo pipefail

HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_BODY="$(cat "$HAPAI_ROOT/templates/guardrails-rules.md")"

# 1. Generate GEMINI.md (Antigravity-specific, takes precedence over AGENTS.md)
INJECT_BLOCK="<!-- hapai:start -->
# Hapai Guardrails

$RULES_BODY
<!-- hapai:end -->"

TARGET="GEMINI.md"

if [[ -f "$TARGET" ]]; then
  if grep -q "<!-- hapai:start -->" "$TARGET" 2>/dev/null; then
    temp_file="$(mktemp)"
    awk '
      /<!-- hapai:start -->/ { skip=1; next }
      /<!-- hapai:end -->/ { skip=0; next }
      !skip { print }
    ' "$TARGET" > "$temp_file"
    echo "" >> "$temp_file"
    echo "$INJECT_BLOCK" >> "$temp_file"
    mv "$temp_file" "$TARGET"
  else
    echo "" >> "$TARGET"
    echo "$INJECT_BLOCK" >> "$TARGET"
  fi
else
  echo "$INJECT_BLOCK" > "$TARGET"
fi

# 2. Also update AGENTS.md for cross-tool compatibility
bash "$HAPAI_ROOT/exporters/export-devin.sh" > /dev/null 2>&1 || true

echo "$TARGET (+ AGENTS.md)"
