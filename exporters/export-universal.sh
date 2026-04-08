#!/usr/bin/env bash
# Exports hapai guardrails as AGENTS.md (cross-tool universal standard)
# Read by: Devin.ai, Antigravity, VS Code Copilot, Trae (auto-import)
# Uses hapai markers for idempotent upsert
set -euo pipefail

# Reuses the devin exporter (same format: AGENTS.md with markers)
HAPAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$HAPAI_ROOT/exporters/export-devin.sh"
