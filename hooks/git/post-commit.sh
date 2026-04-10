#!/usr/bin/env bash
# hapai git post-commit hook
# Fires hapai sync in background after each git commit.
# Works with any AI coding tool that commits via git:
#   Cursor, Windsurf, Devin, Trae, Copilot, Claude Code, or plain git.
#
# Install: hapai install --git-hooks
# Remove:  hapai uninstall --git-hooks

hapai_bin="$(command -v hapai 2>/dev/null)" || exit 0
[[ -z "$hapai_bin" ]] && exit 0

# hapai sync exits quickly when gcp.enabled=false — no overhead when not configured
nohup "$hapai_bin" sync &>/dev/null &
disown 2>/dev/null || true

exit 0
