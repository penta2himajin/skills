---
name: opencode-go
description: >-
  Runs OpenCode CLI with OpenCode Go subscription models, especially
  MiMo-V2.6-Flash (opencode-go/mimo-v2.6-flash). Use when the user asks to call
  OpenCode, OpenCode Go, MiMo, or mimo-v2.6-flash. Not for Ollama.
disable-model-invocation: true
---

# OpenCode Go

Call **OpenCode CLI** with **OpenCode Go** models (not Ollama).

## When to use

- User asks to run / call OpenCode or OpenCode Go
- User names **MiMo-V2.6-Flash** / **mimo** / **mimo-flash**
- Need a one-shot non-interactive `opencode run` from this agent

## Models

| Alias | Slug |
|-------|------|
| `mimo` / `mimo-flash` / `MiMo-V2.6-Flash` | `opencode-go/mimo-v2.6-flash` |

Default: **`opencode-go/mimo-v2.6-flash`**.  
Bare Go ids (e.g. `glm-5.3-flash`) are prefixed with `opencode-go/`. Full `provider/model` slugs pass through.

## How to run

```bash
scripts/run.sh --model mimo --workdir "$PWD" -- "PROMPT"
scripts/run.sh --workdir "$PWD" -- "PROMPT"   # defaults to MiMo-V2.6-Flash
```

From a clone of this repo:

```bash
bash /path/to/skills/opencode-go/scripts/run.sh \
  --model mimo --workdir "$PWD" -- "PROMPT"
```

### Flags

| Flag | Default | Notes |
|------|---------|--------|
| `--model` | `mimo` → `opencode-go/mimo-v2.6-flash` | Alias or `provider/model` |
| `--workdir` | current dir | Project root for the run |
| `--agent` | (OpenCode default) | Optional OpenCode agent name |

### Requirements

1. OpenCode installed (`~/.opencode/bin/opencode` or `opencode` on `PATH`)
2. Logged in with Go access: `opencode auth login` → OpenCode Go / Console key stored
3. Do **not** use `ollama launch` or Ollama base URLs for this skill

Confirm models: `opencode models opencode-go | rg mimo`

## Agent procedure

1. Resolve prompt and workdir from the user.
2. Model: explicit mimo/MiMo alias or slug; else default `opencode-go/mimo-v2.6-flash`.
3. Run `scripts/run.sh` via Shell; set `block_until_ms` high enough (often 60s–180s).
4. Return stdout/stderr; do not hide errors.
5. On auth/binary failure, stop (no Ollama fallback).

## Smoke check

```bash
scripts/run.sh --model mimo -- "Reply with exactly: MIMO FLASH OK. No tools."
```
