#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-files.sh
# Blocks writes to protected files (.env, lockfiles, CI configs).
# Resolves symlinks via realpath to prevent symlink bypass.
# Event: PreToolUse | Matcher: Write|Edit|MultiEdit | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Skip if this hook is already being orchestrated by flow-dispatcher (avoids double-logging)
_is_flow_managed && exit 0

tool_name="$(get_tool_name)"
case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  Bash) ;;
  *) exit 0 ;;
esac

# ── Bash write bypass detection ─────────────────────────────────────────────
# guard-files normally intercepts Write|Edit|MultiEdit tools. This section
# closes the bypass where scripting languages or shell redirects are used
# via Bash to write to protected files without triggering those tools.
if [[ "$tool_name" == "Bash" ]]; then
  enabled_bash="$(config_get "guardrails.file_protection.enabled" "true")"
  [[ "$enabled_bash" != "true" ]] && allow

  bash_cmd="$(get_field '.tool_input.command')"
  [[ -z "$bash_cmd" ]] && allow

  # Protected path patterns (same as file-level checks below)
  _bash_has_ci_path()       { echo "$bash_cmd" | grep -qE '\.github/workflows/' 2>/dev/null; }
  _bash_has_env_path()      {
    echo "$bash_cmd" | grep -qE '\.env' 2>/dev/null || return 1
    # Strip .env.example and .env.sample occurrences, then check if .env remains.
    # POSIX-compatible: avoids grep -P (not available on macOS BSD grep).
    local _stripped
    _stripped="$(echo "$bash_cmd" | sed 's/\.env\.\(example\|sample\)//g')"
    echo "$_stripped" | grep -qE '\.env' 2>/dev/null
  }
  _bash_has_lockfile_path() { echo "$bash_cmd" | grep -qE '(package-lock\.json|pnpm-lock\.yaml|poetry\.lock|uv\.lock|[a-zA-Z0-9._-]+\.lock\b)' 2>/dev/null; }

  _bash_has_protected_path() {
    _bash_has_ci_path || _bash_has_env_path || _bash_has_lockfile_path
  }

  # Pass 1 — Shell-level: redirect / tee / sed -i / perl -i / cp / mv to protected path
  _check_bash_shell_write() {
    local target_pattern='(\.github/workflows/[^ \t\n"'"'"']*|\.env[^ \t\n"'"'"'a-zA-Z]?|package-lock\.json|pnpm-lock\.yaml|poetry\.lock|uv\.lock)'
    # Output redirect (> or >>)
    echo "$bash_cmd" | grep -qE ">>?\s*$target_pattern" 2>/dev/null && return 0
    # tee
    echo "$bash_cmd" | grep -qE "\btee\s+(-a\s+)?$target_pattern" 2>/dev/null && return 0
    # sed in-place
    echo "$bash_cmd" | grep -qE "\bsed\s+(-[a-zA-Z]*i[a-zA-Z]*|--in-place).+$target_pattern" 2>/dev/null && return 0
    # perl in-place
    echo "$bash_cmd" | grep -qE "\bperl\s+.+-i.+$target_pattern" 2>/dev/null && return 0
    # cp / mv to protected destination
    echo "$bash_cmd" | grep -qE "\b(cp|mv)\s+.+\s+$target_pattern" 2>/dev/null && return 0
    return 1
  }

  # Pass 2 — Script-level: scripting language write + protected path anywhere in command
  _check_bash_script_write() {
    _bash_has_protected_path || return 1
    # Python open with write/append mode
    echo "$bash_cmd" | grep -qE "open\s*\([^)]*['\"][wa]['\"]" 2>/dev/null && return 0
    # .write( / .writelines( methods (Python, Ruby)
    echo "$bash_cmd" | grep -qE '\.(write|writelines)\s*\(' 2>/dev/null && return 0
    # Ruby File.write / File.open with write mode
    echo "$bash_cmd" | grep -qE "File\.(write|open)\s*\([^)]*['\"][wa]" 2>/dev/null && return 0
    # Node.js fs write/copy/rename methods
    echo "$bash_cmd" | grep -qE 'fs\.(writeFile|appendFile|writeFileSync|appendFileSync|copyFile|copyFileSync|rename|renameSync)\s*\(' 2>/dev/null && return 0
    # Python file copy/move/rename (shutil, os, pathlib)
    echo "$bash_cmd" | grep -qE '(shutil\.(copy|copyfile|copyfileobj|move)|os\.(rename|replace)|pathlib|Path\s*\([^)]*\)\.(write_text|write_bytes))\s*\(' 2>/dev/null && return 0
    return 1
  }

  _detect_bash_category() {
    _bash_has_ci_path && { echo "ci_workflow"; return; }
    _bash_has_env_path && { echo "environment"; return; }
    _bash_has_lockfile_path && { echo "lockfile"; return; }
    echo "custom_pattern"
  }

  if _check_bash_shell_write; then
    state_increment "guard-files.deny_count"
    file_cat="$(_detect_bash_category)"
    ctx="$(_build_context \
      "bypass_method=bash_redirect" \
      "file_category=$file_cat" \
      "protection_source=hardcoded")"
    deny "hapai: Write blocked — Bash command writes to a protected file via shell redirect/command. Edit the file manually." "$ctx"
  fi

  if _check_bash_script_write; then
    state_increment "guard-files.deny_count"
    file_cat="$(_detect_bash_category)"
    ctx="$(_build_context \
      "bypass_method=scripting_api" \
      "file_category=$file_cat" \
      "protection_source=hardcoded")"
    deny "hapai: Write blocked — Bash command uses a scripting language to write to a protected file. Edit the file manually." "$ctx"
  fi

  allow
fi
# ── End Bash bypass detection ────────────────────────────────────────────────

# Extract file path
file_path="$(get_field '.tool_input.file_path')"
[[ -z "$file_path" ]] && exit 0

# Check if file protection is enabled
enabled="$(config_get "guardrails.file_protection.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Resolve symlinks to prevent bypass (ln -s .env safe.txt → still catches .env)
resolved_path="$file_path"
was_symlink="false"
if command -v realpath &>/dev/null && [[ -e "$file_path" ]]; then
  resolved_real="$(realpath "$file_path" 2>/dev/null || echo "$file_path")"
  [[ "$resolved_real" != "$file_path" ]] && was_symlink="true"
  resolved_path="$resolved_real"
fi

filename="$(basename "$resolved_path")"

# Check temporary blocklist (e.g. hapai block ".env.prod" --type file)
if blocklist_check "$resolved_path" "file" 2>/dev/null || blocklist_check "$filename" "file" 2>/dev/null; then
  state_increment "guard-files.deny_count"
  ctx="$(_build_context \
    "filename=$filename" \
    "file_category=blocklist" \
    "file_fullpath=$resolved_path" \
    "bypass_method=none" \
    "protection_source=blocklist" \
    "was_symlink=$was_symlink")"
  deny "hapai: Write blocked — '$filename' is in the temporary blocklist. Run 'hapai unblock $filename' to remove." "$ctx"
fi

# Check unprotected list first (explicit overrides)
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  # Use quotes to allow bash pattern matching safely (glob expansion from pattern)
  if [[ "$filename" == $pattern ]]; then
    allow
  fi
done <<< "$(config_get_list "guardrails.file_protection.unprotected")"

# Check against protected patterns — emit structured context on deny
_check_protected() {
  local name="$1" path="$2"

  # .env files (but not .env.example / .env.sample)
  if [[ "$name" == ".env" ]]; then
    state_increment "guard-files.deny_count"
    ctx="$(_build_context \
      "filename=$name" \
      "file_category=environment" \
      "file_fullpath=$path" \
      "bypass_method=none" \
      "protection_source=hardcoded" \
      "was_symlink=$was_symlink")"
    deny "hapai: Write blocked — '.env' is a protected file. Environment files should not be modified by AI." "$ctx"
  fi
  if [[ "$name" == .env.* ]] && [[ "$name" != ".env.example" ]] && [[ "$name" != ".env.sample" ]]; then
    state_increment "guard-files.deny_count"
    ctx="$(_build_context \
      "filename=$name" \
      "file_category=environment" \
      "file_fullpath=$path" \
      "bypass_method=none" \
      "protection_source=hardcoded" \
      "was_symlink=$was_symlink")"
    deny "hapai: Write blocked — '$name' is a protected environment file." "$ctx"
  fi

  # Lockfiles
  if [[ "$name" == *.lock ]] || [[ "$name" == "package-lock.json" ]] || [[ "$name" == "pnpm-lock.yaml" ]] || [[ "$name" == "poetry.lock" ]] || [[ "$name" == "uv.lock" ]]; then
    state_increment "guard-files.deny_count"
    ctx="$(_build_context \
      "filename=$name" \
      "file_category=lockfile" \
      "file_fullpath=$path" \
      "bypass_method=none" \
      "protection_source=hardcoded" \
      "was_symlink=$was_symlink")"
    deny "hapai: Write blocked — '$name' is a lockfile. Lockfiles should be generated by package managers, not edited directly." "$ctx"
  fi

  # CI/CD workflow files
  if [[ "$path" == *.github/workflows/* ]]; then
    state_increment "guard-files.deny_count"
    ctx="$(_build_context \
      "filename=$name" \
      "file_category=ci_workflow" \
      "file_fullpath=$path" \
      "bypass_method=none" \
      "protection_source=hardcoded" \
      "was_symlink=$was_symlink")"
    deny "hapai: Write blocked — CI/CD workflow files are protected. Modify workflows manually." "$ctx"
  fi
}

_check_protected "$filename" "$resolved_path"

# Check config-defined protected patterns
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  # Already handled above as defaults
  [[ "$pattern" == ".env" || "$pattern" == ".env.*" || "$pattern" == "*.lock" ]] && continue
  [[ "$pattern" == "package-lock.json" || "$pattern" == "pnpm-lock.yaml" ]] && continue
  [[ "$pattern" == "poetry.lock" || "$pattern" == "uv.lock" ]] && continue
  [[ "$pattern" == ".github/workflows/*" ]] && continue

  # Custom patterns: match filename or path
  # shellcheck disable=SC2053
  if [[ "$filename" == $pattern ]] || [[ "$resolved_path" == */$pattern ]]; then
    state_increment "guard-files.deny_count"
    ctx="$(_build_context \
      "filename=$filename" \
      "file_category=custom_pattern" \
      "file_fullpath=$resolved_path" \
      "bypass_method=none" \
      "protection_source=config" \
      "was_symlink=$was_symlink" \
      "matched_pattern=$pattern")"
    deny "hapai: Write blocked — '$filename' matches protected pattern '$pattern'." "$ctx"
  fi
done <<< "$(config_get_list "guardrails.file_protection.protected")"

allow
