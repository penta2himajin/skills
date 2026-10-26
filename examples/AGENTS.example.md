# AGENTS.md の例: i-have-adhd と japanese-tech-writing の併用

i-have-adhd と japanese-tech-writing は、どちらもエージェントの返答の書き方を決めるので、併用すると規則がぶつかる。i-have-adhd は返答の先頭に次の行動を置き、手順を番号付きの箇条書きにさせる。japanese-tech-writing は段落を論証の単位とするパラグラフライティングを求める。

この例では、エージェントに共通の指示ファイル（AGENTS.md）に優先順位の一文を書いて衝突を解消する。返答の構成（何を先頭に置くか、番号を振るか、箇条書きにするか）は i-have-adhd に従わせ、文の書き方（語の選び方、論証、空句や翻訳調の禁止）は japanese-tech-writing に従わせる。以下のパスと挙動の出典は [docs/agents-md.md](../docs/agents-md.md)（2026-10-26 時点）にまとめてある。

## 共通の AGENTS.md と Claude Code 用の CLAUDE.md に分ける理由

AGENTS.md の規約（[agents.md](https://agents.md)）が定めるのはリポジトリの中のファイルだけで、ユーザー単位のファイルの置き場所はエージェントごとに違う。別のファイルを取り込む import 記法も共通ではなく、`@~/...` の行を展開して本文を読み込むのは Claude Code だけである。ほかのエージェントでは、この行はただの文字列として扱われる。

そこで、この例では二つのファイルに分ける。

- **共通の AGENTS.md**：実体を `~/.agents/AGENTS.md` に置き、各エージェントが読む場所にシンボリックリンクを張る。import に頼らず、優先順位の一文と japanese-tech-writing の要点を本文に直接書く。
- **Claude Code 用の `~/.claude/CLAUDE.md`**：Claude Code が AGENTS.md を読むのはプロジェクトの指示ファイルとしてだけで、ユーザー単位の AGENTS.md を読むとは文書化されていない。そこで、ユーザー単位の `~/.claude/CLAUDE.md` から、共通の AGENTS.md と japanese-tech-writing の全文を import する。

共通の AGENTS.md に規範の全文を貼らないのは、サイズの上限のためである。japanese-tech-writing の `SKILL.md` の本文は 26,733 バイトあり、Antigravity の 1 ファイルあたりの上限（24,000 バイト）を超えて切り詰められる。

## 前提

- i-have-adhd を各エージェントに入れている。Claude Code にはプラグインとして（[recommendation.md](../recommendation.md#i-have-adhd)）、ほかのエージェントには i-have-adhd の [INSTALL.md](https://github.com/ayghri/i-have-adhd/blob/main/INSTALL.md) の手順で入れる。i-have-adhd を入れていないエージェントでは、優先順位の一文のうち i-have-adhd に関する部分は意味を持たない。
- japanese-tech-writing をスキルとして入れている（`npx skills add penta2himajin/skills --skill japanese-tech-writing -g`）。Claude Code では `~/.claude/skills/japanese-tech-writing/` にある前提で import する。

## 共通の AGENTS.md（実体は `~/.agents/AGENTS.md`）

```markdown
# 返答の書き方

チャットの返答の構成（次の行動を先頭に置く、番号付きの手順、箇条書き）は i-have-adhd を優先し、文の書き方（語の選び方、論証、空句・翻訳調の禁止）は下の日本語の文章規範に従う。日本語の技術文書を書くときと推敲するときは、japanese-tech-writing スキルの全文を読む。

## 日本語の文章規範（要点）

- 一つの段落には一つのトピックだけを置き、段落の最初の文で何の話かを示す。
- 推量・可能性・未確認の事柄を、根拠なく断定に変えない。確認していないことを、確認したかのように書かない。
- 因果を主張するときは、なぜそうなるのかを一文で示す。
- 異なるものを「同じ」とまとめない。複数の要因がある事象を単一の原因に還元しない。
- 導入した術語は以後その語で通し、「AI」「ツール」のような広い語に後退しない。分野で慣用されている語を選び、定着したカタカナ語（クライアントシークレット、アクセストークン）を一般語に訳さない。
- 定義していない造語で区分を名付けない。中身で書くか、分野で定着した術語で書く。
- 「重要なのは〜である」「正面から扱う」「掘り下げる」「不可欠」「多角的」のような、論点を増やさない言い回しを使わない。
- 英語の慣用句を直訳した比喩（「〜を運ぶ」「開かれた問い」）や、抽象物を主語にした擬人化（「データが語る」）を使わない。人か処理を主語に戻す。
- 「効く」「刺さる」のような話し言葉の動詞を使わず、効果の中身を書く。
- 推測を「読み」「見立て」「肌感」のような比喩の名詞で書かない。「推測」「仮説」「印象」と地位を名乗り、何から推したかを添える。
- 同じ主張を言い換えて繰り返さない。接続や評価のためだけの文を置かない。
- 太字の強調や決め台詞の演出を多用しない。
- イ形容詞に「です」を続けた文（「難しいです」）を書かない。
```

最後の段落の「スキルの全文を読む」という指示に従うかどうかは、モデルの判断に任される。スキルを毎セッション必ず読み込ませる方法は、どのエージェントにも文書化されていないためである。毎回守らせたい規則は、このように要点として本文に書く。

## エージェントごとの置き場所

| エージェント | 読む場所 | 設定 |
|---|---|---|
| Codex | `~/.codex/AGENTS.md` | `ln -s ~/.agents/AGENTS.md ~/.codex/AGENTS.md` |
| Antigravity（`agy`） | `~/.gemini/AGENTS.md` | `ln -s ~/.agents/AGENTS.md ~/.gemini/AGENTS.md` |
| Gemini CLI | `~/.gemini/AGENTS.md`（Antigravity と同じファイル） | 上のリンクに加え、`~/.gemini/settings.json` の `context.fileName` に `["AGENTS.md", "GEMINI.md"]` を指定する。既定では `GEMINI.md` しか読まない |
| OpenCode | `~/.config/opencode/AGENTS.md` | `ln -s ~/.agents/AGENTS.md ~/.config/opencode/AGENTS.md` |
| pi | `~/.pi/agent/AGENTS.md` | `ln -s ~/.agents/AGENTS.md ~/.pi/agent/AGENTS.md` |
| GitHub Copilot CLI | 環境変数 `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` に挙げたディレクトリの `AGENTS.md` | シェルの設定に `export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="$HOME/.agents"` を足す |
| Cursor | 設定画面の User Rules | AGENTS.md の本文を貼る。ファイルで渡す方法は文書化されていない |
| Claude Code | `~/.claude/CLAUDE.md` | 次の節のとおり import する |

ユーザー単位のファイルをシンボリックリンクにしたときの動作は、どのエージェントの公式文書にも書かれていない。下の「確かめ方」で読み込まれることを確認し、読み込まれないエージェントにはリンクの代わりに複製を置く。

OpenCode は、`~/.config/opencode/AGENTS.md` がないときに `~/.claude/CLAUDE.md` を読む。上のリンクを張れば `~/.claude/CLAUDE.md` は読まないので、次の節の import が OpenCode で二重に読み込まれることはない。

## Claude Code 用の `~/.claude/CLAUDE.md`

```markdown
@~/.agents/AGENTS.md
@~/.claude/skills/japanese-tech-writing/SKILL.md
```

どちらの行も Claude Code の import 記法で、指したファイルの本文を CLAUDE.md の一部として毎セッション読み込ませる。1 行目で共通の AGENTS.md を、2 行目で規範の全文を読み込む。全文は共通の AGENTS.md の要点を含むので、二つを読み込んでも規則は矛盾しない。

スキルとして入れただけでは、エージェントが日本語の技術文書を書くと判断したときにしか規範が読み込まれず、チャットの返答はこの判断に当たらないことが多い。2 行目の import でこれを補う。SessionStart フックで全文を注入しないのは、フックの出力の上限（10,000 文字）に近いためである。`SKILL.md` はフロントマターを除いて 9,339 文字あり、規則を足すと上限を超えて切り詰められる。

## 確かめ方

各エージェントで新しいセッションを開き、返答の書き方の規則を一つ引用させる。共通の AGENTS.md の要点を引用できれば、そのエージェントは AGENTS.md を読み込んでいる。Claude Code では、要点にない規則（見出しを節の結論を言い切るセリフにしない、など）も引用させ、全文が import で読み込まれていることを確かめる。
