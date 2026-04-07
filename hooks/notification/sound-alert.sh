#!/usr/bin/env bash
# hapai/hooks/notification/sound-alert.sh
# Plays a sound when Claude Code needs user input (e.g., permission prompt).
# Lets you step away from the screen without missing prompts.
# macOS: uses afplay with system sounds. Linux: uses paplay or aplay.
# Event: Notification | Timeout: 5s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "observability.notifications.sound_enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get custom sound command from config, or use platform default
sound_cmd="$(config_get "observability.notifications.sound_command" "")"

if [[ -n "$sound_cmd" ]]; then
  # User-configured command (run directly, no eval — split on spaces)
  # shellcheck disable=SC2086
  $sound_cmd &>/dev/null &
elif [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS — use system ping sound
  afplay /System/Library/Sounds/Ping.aiff &>/dev/null &
elif command -v paplay &>/dev/null; then
  # Linux with PulseAudio
  paplay /usr/share/sounds/freedesktop/stereo/bell.oga &>/dev/null &
elif command -v aplay &>/dev/null; then
  # Linux with ALSA
  aplay /usr/share/sounds/alsa/Front_Center.wav &>/dev/null &
else
  # No sound system available — use terminal bell as fallback
  printf '\a' 2>/dev/null || true
fi

audit_log "notify" "Sound alert played"
exit 0
