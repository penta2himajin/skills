# skills

penta2himajin が自作したエージェント用のスキルと、ほかの人のスキルに微調整を加えた版2つを置いている。手元に入れているほかの人のスキルは [recommendation.md](recommendation.md) にまとめてある。

## スキルの一覧

| スキル | 内容 | 想定するエージェント |
|---|---|---|
| [`antigravity-cli`](skills/antigravity-cli/SKILL.md) | Google Antigravity CLI（`agy`）を非対話モードで呼び、作業を委任する。`agy` に校正させ、修正案を Claude が判定して適用するモードもある | Claude Code |
| [`save`](skills/save/SKILL.md) | セッションの作業状態を記録ファイルに書き出して git にコミットし、compaction・/clear・次の起動の後にフックで読み戻す。compaction の要約も同じ構成で書かせる | Claude Code |
| [`research`](skills/research/SKILL.md) | 調べものをバックグラウンドのエージェントに任せ、一次情報に当たった結果を出典付きの Markdown にまとめさせる。mattpocock/skills の research に、エージェント向けの規則を3つ足した版（[recommendation.md](recommendation.md#research-を微調整した版)） | Claude Code |
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

`antigravity-cli`、`save`、`research`、`japanese-tech-writing` の4つを、1つのプラグインとしてまとめて入れる。

```sh
claude plugin marketplace add penta2himajin/skills
claude plugin install penta2himajin-skills@penta2himajin-skills
```

### Cursor に入れる

clone したうえで、スキルのディレクトリを Cursor の Agent Store の `skills/` か、プロジェクトの `.cursor/skills/` にリンクする。

```sh
git clone https://github.com/penta2himajin/skills.git ~/skills
mkdir -p .cursor/skills
ln -s ~/skills/skills/codex-cli .cursor/skills/codex-cli
```

Cursor 用の3つのスキルは、スクリプトを直接実行しても使える。

```sh
~/skills/skills/codex-cli/scripts/run.sh --model astra -- "PROMPT"
```

## スキルごとの前提条件

- **antigravity-cli**: Antigravity CLI（`agy`）とそのログイン
- **save**: 下の「save のフック」の設定。`jq`、`python3`、`git`
- **codex-cli**: ChatGPT デスクトップ版か Codex CLI と、ChatGPT のログイン
- **opencode-go**: OpenCode CLI と OpenCode Go の認証
- **ollama-cli**: Ollama と、クラウドモデル用の `ollama signin`

## save のフック

`save` は、記録を書き出してコミットする部分だけならスキル単体で動く。記録の読み戻しと compaction の要約の誘導には、`~/.claude/settings.json` に次のフックを足す。パスは `~/.claude/skills/save` に入れた場合の例である。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "sh \"$HOME/.claude/skills/save/scripts/restore.sh\"", "timeout": 10 }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto|manual",
        "hooks": [
          { "type": "command", "command": "sh \"$HOME/.claude/skills/save/scripts/precompact.sh\"", "timeout": 10 }
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

- `restore.sh` は、compact では同じセッションの記録を、startup・resume・clear では直前の `/save` の記録を一度だけ注入する。後者は記録が 24 時間より古ければ注入しない。
- `precompact.sh` は、save の書き方の規則と記録の構成を compaction の要約への追加指示として出す。PreCompact フックの標準出力が要約の指示に足されるのは文書化されていない挙動で、Claude Code 2.1.308 で確かめた。挙動がなくなっても、通常の要約に戻るだけである。標準出力があると事前に用意された要約が使われないため、compaction は遅くなる。
- 記録は `~/.claude/projects/<作業ディレクトリ>/save/` に置き、そのディレクトリの git リポジトリにコミットする。リポジトリがなければ作る。`git` が要る。

`nudge.sh` は、コンテキストの量が 600K トークン（環境変数 `SAVE_NUDGE_TOKENS` で変えられる）を超えたときに `/save` の実行を促す。トークン数は `~/.claude/statusline/ctx/<セッション ID>` から読むので、ステータスラインのスクリプトでこのファイルを書き出しておく必要がある。

```sh
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
tokens=$(printf '%s' "$input" | jq -r '.context_window.current_usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens) // empty')
[ -n "$sid" ] && [ -n "$tokens" ] && mkdir -p "$HOME/.claude/statusline/ctx" && printf '%s' "$tokens" >"$HOME/.claude/statusline/ctx/$sid"
```

## ライセンス

[MIT](LICENSE)。ただし `skills/research` は Matt Pocock の著作権表示を含む MIT で、[ディレクトリ内の LICENSE](skills/research/LICENSE) に従う。`skills/japanese-tech-writing` は Unlicense で、[ディレクトリ内の LICENSE](skills/japanese-tech-writing/LICENSE) に従う。
