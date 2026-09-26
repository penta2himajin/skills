---
name: ollama-cli
description: >-
  Runs local Ollama CLI with signed-in Ollama Cloud models glm-5.3-flash and
  deepseek-v4.1-flash. Use when the user asks to call Ollama, ollama run, GLM
  Flash, or DeepSeek V4.1 Flash via CLI. Not for Cursor BYOK Override Base URL.
disable-model-invocation: true
---

# Ollama CLI

Call **Ollama CLI** (`ollama run`) with cloud models via local sign-in (`ollama signin`).  
API key / Cursor Override Base URL は不要。

## When to use

- User asks to run / call Ollama from the terminal
- User names **glm-5.3-flash** or **deepseek-v4.1-flash**
- Need a one-shot non-interactive cloud completion from this agent

## Models

| Alias | Slug |
|-------|------|
| `glm` / `glm-5.3-flash` | `glm-5.3-flash:cloud` |
| `deepseek` / `ds` / `deepseek-v4.1-flash` | `deepseek-v4.1-flash:cloud` |

Default: **`glm-5.3-flash:cloud`**. Other exact Ollama tags pass through.

## How to run

```bash
scripts/run.sh --model glm -- "PROMPT"
scripts/run.sh --model deepseek -- "PROMPT"
```

From a clone of this repo:

```bash
bash /path/to/skills/ollama-cli/scripts/run.sh \
  --model glm -- "PROMPT"
```

### Flags

| Flag | Default | Notes |
|------|---------|--------|
| `--model` | `glm` | `glm` \| `deepseek` \| full tag |
| `--think` | off | Show thinking (`--hidethinking` off) |

### Requirements

1. `ollama` on PATH (or `/usr/local/bin/ollama`)
2. `ollama signin` completed for cloud models
3. Local server at `http://127.0.0.1:11434` (script starts `ollama serve` if needed)

## Agent procedure

1. Resolve prompt; pick `glm` or `deepseek` (default `glm`).
2. Run `scripts/run.sh` via Shell; `block_until_ms` often 30s–120s.
3. Return stdout/stderr; do not hide errors.
4. On auth errors, tell user to run `ollama signin` (do not invent API keys).

## Smoke check

```bash
scripts/run.sh --model glm -- "Reply with exactly: GLM OK"
scripts/run.sh --model deepseek -- "Reply with exactly: DS OK"
```
