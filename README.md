# skills

penta2himajin が自作したエージェント用のスキルと、微調整を加えて置いている他人のスキル1つ。ほかの人のスキルで手元に入れているものは [recommendation.md](recommendation.md) にまとめてある。

## スキルの一覧

| スキル | 内容 | 想定するエージェント |
|---|---|---|
| [`antigravity-cli`](skills/antigravity-cli/SKILL.md) | Google Antigravity CLI（`agy`）を非対話モードで呼び、作業を委任する。`agy` に校正させ、修正案を Claude が判定して適用するモードもある | Claude Code |
| [`save`](skills/save/SKILL.md) | セッションの作業状態を記録ファイルに書き出し、compaction の後にフックで読み戻す | Claude Code |
| [`japanese-tech-writing`](skills/japanese-tech-writing/SKILL.md) | 日本語の技術文書の文章規範。k16shikano 氏の gist に微調整を加えた版で、ライセンスは Unlicense（[recommendation.md](recommendation.md#japanese-tech-writing)） | 問わない |
| [`codex-cli`](skills/codex-cli/SKILL.md) | OpenAI Codex CLI（`astra` / `luna` / `sol`）を呼ぶ。effort は `low` が既定で、`--high` / `--max` も指定できる | Cursor |
| [`opencode-go`](skills/opencode-go/SKILL.md) | OpenCode Go を呼ぶ。既定のモデルは `MiMo-V2.6-Flash` | Cursor |
| [`ollama-cli`](skills/ollama-cli/SKILL.md) | ローカルの Ollama CLI からクラウドモデル（`glm-5.3-flash` / `deepseek-v4.1-flash`）を呼ぶ | Cursor |

## 入れ方

### skills CLI で入れる

[skills CLI](https://github.com/vercel-labs/skills) は `skills/` 配下のスキルを見つけ、指定したエージェントのディレクトリに入れる。

```sh
# 一覧から選ぶ
npx skills add penta2himajin/skills -g

# 名前を指定する
npx skills add penta2himajin/skills --skill save --skill antigravity-cli -g -a claude-code
```

### Claude Code のプラグインとして入れる

`antigravity-cli`、`save`、`japanese-tech-writing` の3つを、1つのプラグインとしてまとめて入れる。

```sh
claude plugin marketplace add penta2himajin/skills
claude plugin install penta2himajin-skills@penta2himajin-skills
```

### Cursor に入れる

clone したうえで、スキルのフォルダを Cursor の Agent Store の `skills/` か、プロジェクトの `.cursor/skills/` にリンクする。

```sh
git clone https://github.com/penta2himajin/skills.git ~/skills
mkdir -p .cursor/skills
ln -s ~/skills/skills/codex-cli .cursor/skills/codex-cli
```

Cursor 用の3つは、スクリプトを直接実行しても使える。

```sh
~/skills/skills/codex-cli/scripts/run.sh --model astra -- "PROMPT"
```

## スキルごとに必要なもの

- **antigravity-cli**: Antigravity CLI（`agy`）とそのログイン
- **save**: 下の「save のフック」の設定。`jq` と `python3`
- **codex-cli**: ChatGPT デスクトップ版か Codex CLI と、ChatGPT のログイン
- **opencode-go**: OpenCode CLI と OpenCode Go の認証
- **ollama-cli**: Ollama と、クラウドモデル用の `ollama signin`

## save のフック

`save` は、記録を書き出す部分だけならスキル単体で動く。compaction の後に記録を自動で読み戻すには、`~/.claude/settings.json` に次のフックを足す。パスは `~/.claude/skills/save` に入れた場合の例である。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          { "type": "command", "command": "sh \"$HOME/.claude/skills/save/scripts/restore.sh\"", "timeout": 10 }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "sh \"$HOME/.claude/skills/save/scripts/nudge.sh\"", "timeout": 5 }
        ]
      }
    ]
  }
}
```

`nudge.sh` は、コンテキストが 600K トークン（環境変数 `SAVE_NUDGE_TOKENS` で変えられる）を超えたときに `/save` を勧める。トークン数は `~/.claude/statusline/ctx/<セッション ID>` から読むので、ステータスラインのスクリプトでこのファイルを書き出しておく必要がある。

```sh
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
tokens=$(printf '%s' "$input" | jq -r '.context_window.current_usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens) // empty')
[ -n "$sid" ] && [ -n "$tokens" ] && mkdir -p "$HOME/.claude/statusline/ctx" && printf '%s' "$tokens" >"$HOME/.claude/statusline/ctx/$sid"
```

`restore.sh` はファイルの更新時刻を BSD の `stat -f` で取るので、そのままでは macOS でしか動かない。

## ライセンス

[MIT](LICENSE)。ただし `skills/japanese-tech-writing` は Unlicense で、[フォルダ内の LICENSE](skills/japanese-tech-writing/LICENSE) に従う。
