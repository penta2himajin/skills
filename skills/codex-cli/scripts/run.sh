#!/usr/bin/env bash
# Run Codex CLI (ChatGPT auth / OpenAI provider). Not Ollama.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--model astra|luna|sol|<slug>] [--high|--max]
         [--sandbox read-only|workspace-write|danger-full-access]
         [--workdir DIR] [--] PROMPT...

Aliases:
  astra -> gpt-6-astra
  luna  -> gpt-6-luna
  sol   -> gpt-6-sol

Effort:
  default -> low
  --high  -> high
  --max   -> max

Note: the aliases are this script's, not Codex's. Bare "sol", "luna" and "astra"
are rejected by the ChatGPT account; the full slugs above are what works.

Examples:
  run.sh --model astra "Summarize this repo"
  run.sh --model astra --high "Hard refactor"
  run.sh --model sol --max --workdir "$PWD" "Adversarial review of this repo"
EOF
}

resolve_codex() {
  if command -v codex >/dev/null 2>&1; then
    command -v codex
    return
  fi
  local bundled="/usr/lib/chatgpt/resources/codex"
  if [[ -x "$bundled" ]]; then
    printf '%s\n' "$bundled"
    return
  fi
  echo "codex not found. Install ChatGPT desktop or put codex on PATH." >&2
  exit 127
}

resolve_model() {
  case "$1" in
    astra|Astra|ASTRA|gpt-6-astra) printf '%s\n' "gpt-6-astra" ;;
    luna|Luna|LUNA|gpt-6-luna) printf '%s\n' "gpt-6-luna" ;;
    sol|Sol|SOL|gpt-6-sol) printf '%s\n' "gpt-6-sol" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

MODEL="gpt-6-astra"
EFFORT="low"
SANDBOX="read-only"
WORKDIR=""
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
    --high)
      EFFORT="high"
      shift
      ;;
    --max)
      EFFORT="max"
      shift
      ;;
    -s|--sandbox)
      [[ $# -ge 2 ]] || { echo "--sandbox requires a value" >&2; exit 2; }
      SANDBOX="$2"
      shift 2
      ;;
    -C|--workdir)
      [[ $# -ge 2 ]] || { echo "--workdir requires a value" >&2; exit 2; }
      WORKDIR="$2"
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

CODEX_BIN="$(resolve_codex)"
ARGS=(
  exec
  -m "$MODEL"
  -s "$SANDBOX"
  --skip-git-repo-check
  -c "model_reasoning_effort=\"${EFFORT}\""
)
if [[ -n "$WORKDIR" ]]; then
  ARGS+=(-C "$WORKDIR")
fi

# Do not use --oss / Ollama. ChatGPT login credentials in ~/.codex are used.
exec "$CODEX_BIN" "${ARGS[@]}" -- "${PROMPT_ARGS[*]}"
