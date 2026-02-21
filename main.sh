#!/usr/bin/env bash
set -u

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLL_SECONDS="${POLL_SECONDS:-1}"
HOOK_TIMEOUT_SECONDS=300
ERROR_LOG="$ROOT_DIR/logs/errors.log"

mkdir -p "$ROOT_DIR/memory" "$ROOT_DIR/inputs.d" "$ROOT_DIR/functions" "$ROOT_DIR/skills" "$ROOT_DIR/logs"

log_error() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$ERROR_LOG"
}


run_with_timeout() { # $1=timeout_secs, rest=command...
  local timeout_secs="$1" cmd="$2" rc
  shift 2
  local label="$(basename "$cmd")${*:+ $*}"
  timeout --signal=TERM --kill-after=5 "${timeout_secs}s" "$cmd" "$@"
  rc=$?
  case "$rc" in
    124|143)
    log_error "$label timed out after ${timeout_secs}s"
    return 124
    ;;
    0) ;;
    *) log_error "$label failed" ;;
  esac
  return "$rc"
}

load_memory() {
  if [[ -x "$ROOT_DIR/memory/load.sh" ]]; then
    run_with_timeout "$HOOK_TIMEOUT_SECONDS" "$ROOT_DIR/memory/load.sh" || { [[ -f "$ROOT_DIR/memory/context.md" ]] && tail -n 500 "$ROOT_DIR/memory/context.md"; }
  elif [[ -f "$ROOT_DIR/memory/context.md" ]]; then
    tail -n 500 "$ROOT_DIR/memory/context.md"
  fi
}

process_response() { # $1=source_name, $2=user_query, $3=codex_response
  if [[ -x "$ROOT_DIR/memory/save.sh" ]]; then
     run_with_timeout "$HOOK_TIMEOUT_SECONDS" "$ROOT_DIR/memory/save.sh" "$1" "$2" "$3" || { printf 'USER: %s\nASSISTANT: %s\n' "$2" "$3" >> "$ROOT_DIR/memory/context.md"; }
  else
    printf 'USER: %s\nASSISTANT: %s\n' "$2" "$3" >> "$ROOT_DIR/memory/context.md"
  fi
}

run_codex() { # $1=user_message, $2=memory_text
  local system_text payload
  system_text="$(cat "$ROOT_DIR/system.md" 2>>"$ERROR_LOG")"
  payload="SYSTEM_PROMPT:\n${system_text}\n\nMEMORY_CONTEXT:\n$2\n\nUSER_INSTRUCTION:\n$1\n"
  if (( VERBOSE )); then
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2> >(tee -a "$ERROR_LOG" >&2)
  else
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2>>"$ERROR_LOG"
  fi
}

printf 'assistant> type a message, or Ctrl-C to quit.\n'

while true; do
  msg=""
  source_name="terminal"
  for plugin in "$ROOT_DIR/inputs.d"/*; do
    [[ -f "$plugin" && -x "$plugin" ]] || continue
    msg="$(run_with_timeout "$HOOK_TIMEOUT_SECONDS" "$plugin" 2>>"$ERROR_LOG")" || continue
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
