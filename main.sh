#!/usr/bin/env bash
set -u

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_TIMEOUT_SECONDS=300
ERROR_LOG="$ROOT_DIR/logs/errors.log"
LOCK_DIR="$ROOT_DIR/memory/.lock"

mkdir -p "$ROOT_DIR/memory" "$ROOT_DIR/inputs.d" "$ROOT_DIR/functions" "$ROOT_DIR/workspace" "$ROOT_DIR/logs"

_lock()   { while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.1; done; }
_unlock() { rmdir "$LOCK_DIR" 2>/dev/null; }

run_with_timeout() { # $1=timeout_secs, rest=command...
  local timeout_secs="$1" cmd="$2" rc
  shift 2
  local label="$(basename "$cmd")${*:+ $*}"
  timeout --signal=TERM --kill-after=5 "${timeout_secs}s" "$cmd" "$@"
  rc=$?
  case "$rc" in
    124|143)
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label timed out after ${timeout_secs}s" >> "$ERROR_LOG"
    return 124
    ;;
    0) ;;
    *) printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label failed" >> "$ERROR_LOG" ;;
  esac
  return "$rc"
}

process_response() { # $1=source_name, $2=user_query, $3=codex_response
  _lock
  if [[ -x "$ROOT_DIR/memory/save.sh" ]]; then
    run_with_timeout "$HOOK_TIMEOUT_SECONDS" "$ROOT_DIR/memory/save.sh" "$1" "$2" "$3" 2>>"$ERROR_LOG"
  fi
  printf 'USER: %s\nASSISTANT: %s\n' "$2" "$3" >> "$ROOT_DIR/memory/context.md"
  _unlock
}

run_codex() { # $1=user_message, $2=memory_text
  local agent_file="$ROOT_DIR/workspace/agent_$$.md"
  printf '# Agent %s\n- request: %s\n' "$$" "${1:0:200}" > "$agent_file"

  local payload="SYSTEM_PROMPT:\n$(cat "$ROOT_DIR/system.md")\n\nMEMORY_CONTEXT:\n$2\n\nAGENT_FILE:\n$agent_file\n\nUSER_INSTRUCTION:\n$1\n"
  if (( VERBOSE )); then
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2> >(tee -a "$ERROR_LOG" >&2)
  else
    printf '%b\n' "$payload" | codex exec --sandbox danger-full-access --yolo --skip-git-repo-check - 2>>"$ERROR_LOG"
  fi
  (( $? )) && printf 'assistant> Error: codex failed, check %s\n' "$ERROR_LOG"

  rm -f "$agent_file"
}

handle_message() { # $1=source_name, $2=message
  local memory_text response
  memory_text="$(tail -n 500 "$ROOT_DIR/memory/context.md" 2>/dev/null)"
  printf '\nassistant> Receive message from [%s], processing...\n' "$1"
  response="$(run_codex "$2" "$memory_text")"
  printf '%s\n' "$response"
  printf '================end of response=================\n'
  process_response "$1" "$2" "$response"
}

trap 'rmdir "$LOCK_DIR" 2>/dev/null; rm -f "$ROOT_DIR"/workspace/agent_*.md; kill 0 2>/dev/null; wait' EXIT

printf 'assistant> type a message, or Ctrl-C to quit.\n'

while true; do
  for plugin in "$ROOT_DIR/inputs.d"/*; do
    [[ -f "$plugin" && -x "$plugin" ]] || continue
    (
      msg="$(run_with_timeout "$HOOK_TIMEOUT_SECONDS" "$plugin" 2>>"$ERROR_LOG")" || exit 0
      [[ -z "$msg" ]] && exit 0
      handle_message "$(basename "$plugin")" "$msg"
    ) &
  done

  if IFS= read -r -t 2 line && [[ -n "$line" ]]; then
    handle_message "terminal" "$line" &
  fi
done
