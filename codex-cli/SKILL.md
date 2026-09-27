---
name: codex-cli
description: >-
  Runs OpenAI Codex CLI (ChatGPT desktop bundled binary) with ChatGPT auth.
  Use when the user asks to call Codex, run Codex CLI, or use models astra /
  luna / sol (gpt-6-astra / gpt-6-luna / gpt-6-sol). Reasoning effort defaults
  to low; pass --high or --max. Not for Ollama.
disable-model-invocation: true
---

# Codex CLI

Call **OpenAI Codex CLI** (not Ollama) via the helper script.

## When to use

- User asks to run / call Codex CLI
- User names **astra**, **luna** or **sol** as the Codex model
- Need a one-shot non-interactive Codex exec from this agent

## Models

| Alias | Slug | Verified |
|-------|------|----------|
| `astra` | `gpt-6-astra` | yes |
| `luna` | `gpt-6-luna` | yes |
| `sol` | `gpt-6-sol` | yes |

Default: **astra**. Pass full slugs through unchanged if given.

The aliases live in this script, not in Codex. Passing a bare `astra`, `luna` or `sol`
straight to Codex fails with HTTP 400 ("not supported when using Codex with a ChatGPT
account"), and `gpt-6-sol-max` fails the same way: the effort level is a separate setting,
not part of the slug. Always go through `run.sh` so the alias resolves.

## Effort

| Flag | Effort |
|------|--------|
| (default) | `low` |
| `--high` | `high` |
| `--max` | `max` |

`--max` is the slowest and most thorough; on a full-repository review it consumed ~192k
tokens in one run. Use it for hard analysis, not for routine work.

## How to run

```bash
scripts/run.sh --model astra --workdir "$PWD" -- "PROMPT"
scripts/run.sh --model astra --high --workdir "$PWD" -- "PROMPT"
scripts/run.sh --model luna  --workdir "$PWD" -- "PROMPT"
scripts/run.sh --model sol --max --workdir "$PWD" -- "PROMPT"
```

From a clone of this repo:

```bash
bash /path/to/skills/codex-cli/scripts/run.sh \
  --model astra --workdir "$PWD" -- "PROMPT"
```

### Flags

| Flag | Default | Notes |
|------|---------|--------|
| `--model` | `astra` | `astra` \| `luna` \| `sol` \| any Codex slug |
| `--high` | off | Sets effort to `high` (otherwise `low`) |
| `--max` | off | Sets effort to `max` (otherwise `low`) |
| `--sandbox` | `read-only` | Prefer `read-only` unless writes are needed |
| `--workdir` | Codex cwd | Set to the project root the user cares about |

### Requirements

1. ChatGPT desktop installed (provides `/usr/lib/chatgpt/resources/codex`), **or** `codex` on `PATH`
2. Logged in once (`codex login` / ChatGPT auth → `~/.codex/auth.json`)
3. Do **not** pass `--oss` or `--local-provider ollama`

## Agent procedure

1. Resolve prompt from the user (and workdir if a project is in scope).
2. Pick model: explicit `astra`/`luna`/`sol`/slug, else default `astra`.
3. Effort: `low` by default; `--high` for harder reasoning; `--max` for the hardest
   analysis where a long run is acceptable.
4. Run `scripts/run.sh` with Shell; set `block_until_ms` high enough (often 60s–180s; longer with `--high`).
5. Return Codex stdout/stderr to the user; do not hide errors.
6. If binary missing or auth fails, report that and stop (do not fall back to Ollama).

## Smoke check

```bash
scripts/run.sh --model astra -- "Reply with exactly: CODEX ASTRA OK. No tools."
scripts/run.sh --model astra --high -- "Reply with exactly: CODEX HIGH OK. No tools."
scripts/run.sh --model sol --max -- "Reply with exactly: CODEX SOL MAX OK. No tools."
```

The last check is slow. A one-word answer under `--max` still took about 19k tokens, because
reasoning effort is charged before the reply is emitted.
