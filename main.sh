#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLL_SECONDS="${POLL_SECONDS:-1}"
ERROR_LOG="$ROOT_DIR/logs/errors.log"

mkdir -p "$ROOT_DIR/memory" "$ROOT_DIR/inputs.d" "$ROOT_DIR/functions" "$ROOT_DIR/skills" "$ROOT_DIR/logs"

log_error() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$ERROR_LOG"
}

load_memory() {
  if [[ -x "$ROOT_DIR/memory/load.sh" ]]; then
    "$ROOT_DIR/memory/load.sh" || { log_error "memory/load.sh failed"; [[ -f "$ROOT_DIR/memory/context.md" ]] && tail -n 500 "$ROOT_DIR/memory/context.md"; }
  elif [[ -f "$ROOT_DIR/memory/context.md" ]]; then
    tail -n 500 "$ROOT_DIR/memory/context.md"
  fi
}

process_response() { # $1=source_name, $2=user_query, $3=codex_response
  if [[ -x "$ROOT_DIR/memory/save.sh" ]]; then
     "$ROOT_DIR/memory/save.sh" "$1" "$2" "$3" || { log_error "memory/save.sh failed"; printf 'USER: %s\nASSISTANT: %s\n' "$2" "$3" >> "$ROOT_DIR/memory/context.md"; }
  else
    printf 'USER: %s\nASSISTANT: %s\n' "$2" "$3" >> "$ROOT_DIR/memory/context.md"
  fi
}

run_codex() { # $1=user_message, $2=memory_text
  local payload="$(cat <<EOT
SYSTEM_PROMPT:
$(cat "$ROOT_DIR/system.md")

MEMORY_CONTEXT:
$2

USER_INSTRUCTION:
$1

EOT
)"

  printf '%s\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2>>"$ERROR_LOG"
}

printf 'assistant> type a message, or Ctrl-C to quit.\n'

while true; do
  msg=""
  source_name="terminal"
  for plugin in "$ROOT_DIR/inputs.d"/*; do
    [[ -f "$plugin" && -x "$plugin" ]] || continue
    msg="$($plugin 2>>"$ERROR_LOG")" || { log_error "input plugin failed: $plugin"; continue; }
    if [[ -n "$msg" ]]; then
      source_name="$(basename "$plugin")"
      break
    fi
  done

  if [[ -z "$msg" ]] && IFS= read -r -t "$POLL_SECONDS" line && [[ -n "$line" ]]; then
    msg="$line"
  fi
  [[ -z "$msg" ]] && { sleep "$POLL_SECONDS"; continue; }

  memory_text="$(load_memory || true)"
  printf 'assistant> processing...\n'
  response="$(run_codex "$msg" "$memory_text")" || response="assistant> error: codex failed, check $ERROR_LOG"
  printf '%s\n' "$response"
  printf '================end of response=================\n'
  process_response "$source_name" "$msg" "$response"

  done
