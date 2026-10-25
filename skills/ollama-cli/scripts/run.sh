#!/usr/bin/env bash
# Run Ollama CLI with signed-in cloud models. Not Cursor BYOK.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--model glm|deepseek|glm-5.3-flash|deepseek-v4.1-flash|<name>]
         [--think] [--] PROMPT...

Aliases (Ollama Cloud via local sign-in):
  glm | glm-5.3-flash | GLM-5.3-Flash
      -> glm-5.3-flash:cloud
  deepseek | ds | deepseek-v4.1-flash | DeepSeek-V4.1-Flash
      -> deepseek-v4.1-flash:cloud

Default model: glm-5.3-flash:cloud

Examples:
  run.sh --model glm "Summarize this idea in one sentence"
  run.sh --model deepseek "Explain this error"
EOF
}

resolve_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    command -v ollama
    return
  fi
  for p in /usr/local/bin/ollama /usr/bin/ollama; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return
    fi
  done
  echo "ollama not found. Install Ollama and run: ollama signin" >&2
  exit 127
}

resolve_model() {
  case "$1" in
    glm|GLM|glm-flash|glm-5.3-flash|GLM-5.3-Flash|glm-5.3-flash:cloud)
      printf '%s\n' "glm-5.3-flash:cloud"
      ;;
    deepseek|ds|DS|deepseek-flash|deepseek-v4.1-flash|DeepSeek-V4.1-Flash|deepseek-v4.1-flash:cloud)
      printf '%s\n' "deepseek-v4.1-flash:cloud"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

ensure_server() {
  if curl -sf --max-time 2 "http://127.0.0.1:11434/api/version" >/dev/null 2>&1; then
    return 0
  fi
  nohup ollama serve >/dev/null 2>&1 &
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf --max-time 1 "http://127.0.0.1:11434/api/version" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
  done
  echo "ollama server not reachable at http://127.0.0.1:11434" >&2
  exit 1
}

MODEL="glm-5.3-flash:cloud"
THINK=0
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
    --think)
      THINK=1
      shift
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

OLLAMA_BIN="$(resolve_ollama)"
PATH="$(dirname "$OLLAMA_BIN"):$PATH"
ensure_server

PROMPT="${PROMPT_ARGS[*]}"
ARGS=(run "$MODEL")
if [[ "$THINK" -eq 0 ]]; then
  ARGS+=(--hidethinking)
fi
ARGS+=("$PROMPT")

# Strip ANSI / spinner noise for agent-friendly stdout.
set +e
OUT="$("$OLLAMA_BIN" "${ARGS[@]}" 2>/dev/null)"
STATUS=$?
set -e
printf '%s\n' "$OUT" | python3 -c '
import re, sys
text = sys.stdin.read()
text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text)
text = re.sub(r"\r", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).strip()
print(text)
'
exit "$STATUS"
