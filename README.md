# skills

Personal Cursor Agent Skills for CLI coding agents.

| Skill | Purpose |
|-------|---------|
| `codex-cli` | OpenAI Codex CLI (`astra` / `luna` / `sol`), effort `low` default, `--high` / `--max` optional |
| `opencode-go` | OpenCode Go, default `MiMo-V2.6-Flash` |
| `ollama-cli` | Local Ollama CLI cloud models (`glm-5.3-flash` / `deepseek-v4.1-flash`) |

## Install on another machine

```bash
git clone git@github.com:penta2himajin/skills.git ~/skills
# or: gh repo clone penta2himajin/skills ~/skills
```

### Option A — Cursor personal Agent Store

Copy (or symlink) skill folders into your user Agent Store `skills/` directory, then restart Cursor / start a new agent chat so they are discovered.

### Option B — project skills

```bash
mkdir -p .cursor/skills
ln -s ~/skills/codex-cli .cursor/skills/codex-cli
ln -s ~/skills/opencode-go .cursor/skills/opencode-go
ln -s ~/skills/ollama-cli .cursor/skills/ollama-cli
```

### Option C — run scripts directly

```bash
~/skills/codex-cli/scripts/run.sh --model astra -- "PROMPT"
~/skills/opencode-go/scripts/run.sh --model mimo -- "PROMPT"
~/skills/ollama-cli/scripts/run.sh --model glm -- "PROMPT"
```

Each skill’s `SKILL.md` has flags, model aliases, and requirements.

## Requirements (by skill)

- **codex-cli**: ChatGPT desktop / Codex CLI + ChatGPT login
- **opencode-go**: OpenCode CLI + OpenCode Go auth
- **ollama-cli**: Ollama + `ollama signin` for cloud models
