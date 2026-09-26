---
name: codex-cli
description: >-
  Runs OpenAI Codex CLI (ChatGPT desktop bundled binary) with ChatGPT auth.
  Use when the user asks to call Codex, run Codex CLI, or use models astra /
  luna (gpt-6-astra / gpt-6-luna). Reasoning effort defaults to low; pass
  --high for high. Not for Ollama.
disable-model-invocation: true
---

# Codex CLI

Call **OpenAI Codex CLI** (not Ollama) via the helper script.

## When to use

- User asks to run / call Codex CLI
- User names **astra** or **luna** as the Codex model
- Need a one-shot non-interactive Codex exec from this agent

## Models

| Alias | Slug |
|-------|------|
| `astra` | `gpt-6-astra` |
| `luna` | `gpt-6-luna` |

Default: **astra**. Pass full slugs through unchanged if given.

## Effort

| Flag | Effort |
|------|--------|
| (default) | `low` |
| `--high` | `high` |

Other effort levels are not supported by this skill.

## How to run

```bash
scripts/run.sh --model astra --workdir "$PWD" -- "PROMPT"
scripts/run.sh --model astra --high --workdir "$PWD" -- "PROMPT"
scripts/run.sh --model luna  --workdir "$PWD" -- "PROMPT"
```

From a clone of this repo:

```bash
bash /path/to/skills/codex-cli/scripts/run.sh \
  --model astra --workdir "$PWD" -- "PROMPT"
```

### Flags

| Flag | Default | Notes |
|------|---------|--------|
| `--model` | `astra` | `astra` \| `luna` \| any Codex slug |
| `--high` | off | Sets effort to `high` (otherwise `low`) |
| `--sandbox` | `read-only` | Prefer `read-only` unless writes are needed |
| `--workdir` | Codex cwd | Set to the project root the user cares about |

### Requirements

1. ChatGPT desktop installed (provides `/usr/lib/chatgpt/resources/codex`), **or** `codex` on `PATH`
2. Logged in once (`codex login` / ChatGPT auth → `~/.codex/auth.json`)
3. Do **not** pass `--oss` or `--local-provider ollama`

## Agent procedure

1. Resolve prompt from the user (and workdir if a project is in scope).
2. Pick model: explicit `astra`/`luna`/slug, else default `astra`.
3. Effort: `low` unless the user asks for high / harder reasoning → then `--high`.
4. Run `scripts/run.sh` with Shell; set `block_until_ms` high enough (often 60s–180s; longer with `--high`).
5. Return Codex stdout/stderr to the user; do not hide errors.
6. If binary missing or auth fails, report that and stop (do not fall back to Ollama).

## Smoke check

```bash
scripts/run.sh --model astra -- "Reply with exactly: CODEX ASTRA OK. No tools."
scripts/run.sh --model astra --high -- "Reply with exactly: CODEX HIGH OK. No tools."
```
