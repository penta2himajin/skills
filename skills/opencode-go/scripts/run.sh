#!/usr/bin/env bash
# Run OpenCode CLI with OpenCode Go models. Not Ollama.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--model mimo|mimo-flash|mimo-v2.6-flash|<provider/model>]
         [--workdir DIR] [--agent NAME] [--] PROMPT...

Aliases (OpenCode Go):
  mimo | mimo-flash | mimo-v2.6-flash | MiMo-V2.6-Flash
      -> opencode-go/mimo-v2.6-flash

Default model: opencode-go/mimo-v2.6-flash

Examples:
  run.sh --model mimo "Summarize this repo"
  run.sh --workdir /path/to/proj -- "Fix the failing test"
EOF
}

resolve_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    command -v opencode
    return
  fi
  local home_bin="${HOME}/.opencode/bin/opencode"
  if [[ -x "$home_bin" ]]; then
    printf '%s\n' "$home_bin"
    return
  fi
  echo "opencode not found. Install from https://opencode.ai/docs and auth login for OpenCode Go." >&2
  exit 127
}

resolve_model() {
  case "$1" in
    mimo|Mimo|MIMO|mimo-flash|mimo-v2.6-flash|MiMo-V2.6-Flash|mimo-v2.6.flash)
      printf '%s\n' "opencode-go/mimo-v2.6-flash"
      ;;
    */*)
      # Already provider/model
      printf '%s\n' "$1"
      ;;
    *)
      # Bare Go model id -> prefix provider
      printf '%s\n' "opencode-go/$1"
      ;;
  esac
}

MODEL="opencode-go/mimo-v2.6-flash"
WORKDIR=""
AGENT=""
PROMPT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -m|--model)
      [[ $# -ge 2 ]] || { echo "--model requires a value" >&2; exit 2; }
      MODEL="$(resolve_model "$2")"
      shift 2
      ;;
    -C|--workdir|--dir)
      [[ $# -ge 2 ]] || { echo "--workdir requires a value" >&2; exit 2; }
      WORKDIR="$2"
      shift 2
      ;;
    --agent)
      [[ $# -ge 2 ]] || { echo "--agent requires a value" >&2; exit 2; }
      AGENT="$2"
      shift 2
      ;;
    --)
      shift
      PROMPT_ARGS+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PROMPT_ARGS+=("$@")
      break
      ;;
  esac
done

if [[ ${#PROMPT_ARGS[@]} -eq 0 ]]; then
  echo "PROMPT is required" >&2
  usage >&2
  exit 2
fi

OC_BIN="$(resolve_opencode)"
ARGS=(run --standalone --auto -m "$MODEL")
if [[ -n "$AGENT" ]]; then
  ARGS+=(--agent "$AGENT")
fi

if [[ -n "$WORKDIR" ]]; then
  cd "$WORKDIR"
fi

# OpenCode Go credentials come from `opencode auth` (OpenCode Console).
# Do not use Ollama for this skill.
exec "$OC_BIN" "${ARGS[@]}" -- "${PROMPT_ARGS[*]}"
