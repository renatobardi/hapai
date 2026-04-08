#!/usr/bin/env bash
# Exports hapai guardrails into AGENTS.md (used by Devin.ai)
# Uses hapai markers for idempotent upsert (append or replace existing block)
set -euo pipefail

HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_BODY="$(cat "$HAPAI_ROOT/templates/guardrails-rules.md")"
TARGET="AGENTS.md"

INJECT_BLOCK="<!-- hapai:start -->
# Hapai Guardrails

$RULES_BODY
<!-- hapai:end -->"

if [[ -f "$TARGET" ]]; then
  if grep -q "<!-- hapai:start -->" "$TARGET" 2>/dev/null; then
    # Upsert: replace existing block
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
    # Append
    echo "" >> "$TARGET"
    echo "$INJECT_BLOCK" >> "$TARGET"
  fi
else
  echo "$INJECT_BLOCK" > "$TARGET"
fi

echo "$TARGET"
