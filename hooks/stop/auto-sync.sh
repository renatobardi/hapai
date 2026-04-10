#!/usr/bin/env bash
set -euo pipefail
# hapai/hooks/stop/auto-sync.sh
# Uploads audit.jsonl to GCS at the end of each Claude Code session.
# Runs hapai sync in background — does not block session teardown.
# Event: Stop | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Opt-in: gcp.auto_sync.enabled must be true
enabled="$(config_get "gcp.auto_sync.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# GCP integration must also be enabled
gcp_enabled="$(config_get "gcp.enabled" "false")"
[[ "$gcp_enabled" != "true" ]] && exit 0

# Nothing to upload if audit log is missing or empty
[[ ! -s "$HAPAI_AUDIT_LOG" ]] && exit 0

# Resolve hapai binary
hapai_bin="$(command -v hapai 2>/dev/null)" || hapai_bin=""
[[ -z "$hapai_bin" ]] && exit 0

# Fire-and-forget: sync runs in background so session teardown is not delayed
nohup "$hapai_bin" sync &>/dev/null &
disown 2>/dev/null || true

exit 0
