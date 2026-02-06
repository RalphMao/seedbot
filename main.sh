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
    "$ROOT_DIR/memory/load.sh" || { log_error "memory/load.sh failed"; [[ -f "$ROOT_DIR/memory/context.md" ]] && cat "$ROOT_DIR/memory/context.md"; }
  elif [[ -f "$ROOT_DIR/memory/context.md" ]]; then
    head -n 50 "$ROOT_DIR/memory/context.md"
  fi
}

save_memory() {
  local entry="$1"
  if [[ -x "$ROOT_DIR/memory/save.sh" ]]; then
    printf '%s\n' "$entry" | "$ROOT_DIR/memory/save.sh" || { log_error "memory/save.sh failed"; printf '%s\n' "$entry" >> "$ROOT_DIR/memory/context.md"; }
  else
    printf '%s\n' "$entry" >> "$ROOT_DIR/memory/context.md"
  fi
}

collect_messages() {
  local got=0 plugin output
  shopt -s nullglob
  for plugin in "$ROOT_DIR/inputs.d"/*.sh; do
    [[ -x "$plugin" ]] || continue
    got=1
    output="$($plugin 2>>"$ERROR_LOG")" || { log_error "input plugin failed: $plugin"; continue; }
    [[ -n "$output" ]] && printf '%s\n' "$output"
  done
  shopt -u nullglob

  if [[ $got -eq 0 ]]; then
    IFS= read -r -t "$POLL_SECONDS" line && [[ -n "$line" ]] && printf '%s\n' "$line"
  fi
}

run_codex() {
  local user_message="$1"
  local memory_text="$2"
  local system_text payload

  system_text="$(cat "$ROOT_DIR/system.md" 2>>"$ERROR_LOG")"
  payload="$(cat <<EOT
SYSTEM_PROMPT:
$system_text

MEMORY_DIR: $ROOT_DIR/memory
MEMORY_CONTEXT:
$memory_text

USER_INSTRUCTION:
$user_message

EOT
)"

  printf '%s\n' "$payload" | codex exec --full-auto --skip-git-repo-check - 2>>"$ERROR_LOG"
}

printf 'assistant> ready. type a message, or /exit to quit.\n'

while true; do
  messages="$(collect_messages)"
  [[ -z "$messages" ]] && { sleep "$POLL_SECONDS"; continue; }

  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    [[ "$msg" == "/exit" ]] && { printf 'assistant> bye.\n'; exit 0; }
    memory_text="$(load_memory || true)"
    printf 'assistant> processing...\n'
    if response="$(run_codex "$msg" "$memory_text")"; then
      printf '%s\n' "$response"
      save_memory "USER: $msg
ASSISTANT: $response"
    else
      printf 'assistant> error: codex failed, check %s\n' "$ERROR_LOG"
      printf 'assistant> failed.\n'
      save_memory "USER: $msg
ASSISTANT: error: codex failed"
    fi
  done <<< "$messages"

  sleep "$POLL_SECONDS"
done
