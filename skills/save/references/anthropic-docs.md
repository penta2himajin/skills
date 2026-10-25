# Claude Code / Claude API のコンテキスト運用とコンパクション（一次資料調査）

- 調査日: 2026-10-20
- 対象: Anthropic の一次資料（code.claude.com、platform.claude.com、anthropic.com/engineering、claude.com/blog）のみ
- 方法: 各ページの現行版を取得して本文を確認した。Claude Code のドキュメントは `https://code.claude.com/docs/en/<page>.md`、API のドキュメントは `https://platform.claude.com/docs/en/<path>.md` で Markdown 版を取得した。
- 表記: 「未確認」は、読んだページに記述が見つからなかったことを表す（仕様が存在しないことの確認ではない）。バージョン番号（v2.1.xxx）はページに書かれていたものをそのまま写した。

## 目次

1. Claude Code のコンパクション仕様
2. コンパクション関連フック（PreCompact / PostCompact / SessionStart / InstructionsLoaded）
3. コンパクション後に何が残り、何が再注入されるか
4. Skill の仕様（frontmatter、呼び出し、progressive disclosure、コンパクション時の扱い）
5. Claude API 側のコンテキスト管理（compaction API、context editing、memory tool）
6. エンジニアリングブログの知見
7. プロンプトガイドの推奨（コンテキストウィンドウをまたぐ状態管理）
8. 未確認事項
9. /refresh 設計への含意

---

## 1. Claude Code のコンパクション仕様

### 自動コンパクション（auto-compact）

- コンテキストが上限に近づくと、Claude Code はまず古いツール出力を消し、必要ならその後で会話を要約する。要求と主要なコード断片は残るが、会話の早い段階で与えた詳細な指示は失われることがある。恒久的なルールは会話履歴に頼らず CLAUDE.md に置くよう推奨されている。
  - https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up
- 単一のファイルやツール出力が大きすぎて要約直後にまた満杯になる場合、数回試した後に自動コンパクションを止めてエラーを出す（ループしない）。
  - https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up
- 自動コンパクションが走る閾値（auto-compact window）は `/autocompact <tokens>`（例 `/autocompact 500k`）、設定キー `autoCompactWindow`、起動フラグ `--autocompact`、環境変数 `CLAUDE_CODE_AUTO_COMPACT_WINDOW`（100,000〜1,000,000）で変えられる。環境変数がほかより優先される。
  - https://code.claude.com/docs/en/model-config#set-the-auto-compact-window
  - https://code.claude.com/docs/en/commands
- 既定では、auto-compact window を設定しなければモデルのコンテキスト上限に達した時点でコンパクションする（例外: クラウドセッション、拡張コンテキストなしの Sonnet 4.6 / Opus 4.6 は 200K 境界など）。
  - https://code.claude.com/docs/en/model-config#default-auto-compact-thresholds
- 無効化: `DISABLE_AUTO_COMPACT=1` で自動コンパクションとアイドルコンパクションを止める（手動 `/compact` は使える）。`DISABLE_COMPACT=1` は手動も含めすべて止める。設定キー `autoCompactEnabled: false` でも自動を止められ、その場合アイドルコンパクションも止まる。`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` で閾値を早める（引き上げはできない）。
  - https://code.claude.com/docs/en/env-vars
  - https://code.claude.com/docs/en/settings-reference#autocompactenabled

### アイドルコンパクション（idle compaction）

- 対話型ターミナルセッションで、1 時間のプロンプトキャッシュ TTL 上にあり、コンテキストが閾値（既定 200,000 トークン、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` で変更可）に達し、最後のリクエストから約 54 分経過したとき、キャッシュが切れる直前に会話をコンパクションする。復帰すると `Compacted while idle, before the prompt cache expired` と表示される。`idleCompaction: false` で無効化。
  - https://code.claude.com/docs/en/settings-reference#idlecompaction
  - https://code.claude.com/docs/en/env-vars
- PreCompact / PostCompact フックの matcher `auto` はアイドルコンパクションでも発火する（後述）。
  - https://code.claude.com/docs/en/hooks#precompact

### 手動コンパクション `/compact [instructions]`

- `/compact [instructions]`: 会話を要約してコンテキストを空ける。要約の焦点を指示として渡せる。
  - https://code.claude.com/docs/en/commands
- 例: `/compact Focus on code samples and API usage`、`/compact focus on the API changes`。
  - https://code.claude.com/docs/en/costs#manage-context-proactively
  - https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up
- 新しい長いタスクを始める前に焦点付きで `/compact` すると、自動パスが推測する内容ではなく自分の選んだ内容が要約に残る。
  - https://code.claude.com/docs/en/context-window#when-your-context-fills-up
- 部分的な要約: `/rewind`（または空の入力欄で `Esc` 2 回）でメッセージを選び、**Summarize from here** または **Summarize up to here** を選ぶ。
  - https://code.claude.com/docs/en/best-practices#manage-context-aggressively
  - https://code.claude.com/docs/en/checkpointing#rewind-and-summarize
- `/compact` 自体が要約対象の会話全体を読むので、大きなコンテキストのコンパクションはそれ自体が大きなリクエストになる。継続性が不要なら `/clear` はコストがかからない。
  - https://code.claude.com/docs/en/costs#why-usage-climbs-in-a-long-session
- v2.1.198 以降、要約リクエストはセッションの extended thinking 設定を引き継ぐ。
  - https://code.claude.com/docs/en/context-window#what-survives-compaction

### CLAUDE.md に書く compact 指示

- CLAUDE.md に "Compact Instructions" 節を置くと、コンパクションで何を残すかを制御できる。
  - https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up
- 例（costs ページ掲載）:
  ```markdown
  # Compact instructions

  When you are using compact, please focus on test output and code changes
  ```
  - https://code.claude.com/docs/en/costs#manage-context-proactively
- 別の例: `"When compacting, always preserve the full list of modified files and any test commands"`。
  - https://code.claude.com/docs/en/best-practices#manage-context-aggressively
- 見出し名の厳密な形式（`# Compact instructions` 固定か、本文中の指示として読まれるだけか）は未確認。ページによって "Compact Instructions" 節／`# Compact instructions` 見出し／自由文の指示と書き方が揺れている。

### Claude Code の要約が保持する内容（公式の記述）

- context-window ページの対話型図の説明文: 要約は「ユーザーの要求と意図、主要な技術概念、調べた／変更したファイルと重要なコード断片、エラーとその修正、未完のタスク、現在の作業」を保持し、ツール出力の全文と途中の推論は消える。
  - https://code.claude.com/docs/en/context-window （ページ内の対話型タイムラインの説明文）
- best-practices: 自動コンパクションは「コードパターン、ファイルの状態、主要な決定」を要約する。
  - https://code.claude.com/docs/en/best-practices#manage-context-aggressively
- 要約プロンプトの全文は Claude Code については公開を確認できなかった（未確認）。API の client-side SDK compaction の既定プロンプトは公開されている（5 節）。

### 再開時のトランスクリプト

- トランスクリプトは `~/.claude/projects/<project>/<session-id>.jsonl`（`<project>` は作業ディレクトリのパスの英数字以外を `-` に置換したもの）。
  - https://code.claude.com/docs/en/sessions#where-transcripts-are-stored
- コンパクション済みのセッションを再開すると `Conversation compacted` 行から開き、最後のコンパクションの要約、コンパクションが要約しなかったメッセージ、それ以降のメッセージで続く。要約済みのメッセージは再読込されない。
  - https://code.claude.com/docs/en/sessions

---

## 2. コンパクション関連フック

出典はすべて https://code.claude.com/docs/en/hooks （以下「hooks」）と https://code.claude.com/docs/en/hooks-guide （以下「hooks-guide」）。

### 共通入力（stdin JSON）

- `session_id`、`prompt_id`（最初のユーザー入力まで無い）、`transcript_path`、`cwd`、`scratchpad_dir`（v2.1.257 以降、無い場合あり）、`permission_mode`（イベントによっては無い）、`effort`（ツール使用文脈のイベントのみ）、`hook_event_name`。サブエージェント内では `agent_id` / `agent_type`。
  - hooks#common-input-fields
- `transcript_path` のファイルは非同期に書かれ、フック発火時点で最新ターンを含まない場合がある。
  - hooks#common-input-fields
- フックのタイプ: `command` / `http` / `mcp_tool` / `prompt` / `agent`。ただし PreCompact・PostCompact は `command`・`http`・`mcp_tool` のみ（`prompt`・`agent` 不可）。SessionStart は `command` と `mcp_tool` のみ。
  - hooks（"Events that support command, http, and mcp_tool hooks but not prompt or agent" の一覧）
  - hooks#sessionstart

### PreCompact

- 発火: コンパクション実行の直前。matcher は `manual`（`/compact`）と `auto`（auto-compact window 到達、およびアイドルコンパクション）。
  - hooks#precompact
- 入力: 共通項目に加えて `trigger` と `custom_instructions`。`manual` のとき `custom_instructions` は `/compact` に渡した文字列（無指定なら `null`）、`auto` のときは `null`。
  ```json
  {"session_id":"abc123","transcript_path":"...jsonl","cwd":"...","hook_event_name":"PreCompact","trigger":"manual","custom_instructions":null}
  ```
  - hooks#precompact-input
- 出力・制御: exit 2 または JSON `"decision": "block"` でコンパクションを止められる。自動コンパクションをブロックした場合、上限前の予防的コンパクションならスキップされて会話が続くが、API が既にコンテキスト上限エラーを返した後の回復目的なら元のエラーが表に出て現在のリクエストが失敗する。`systemMessage` と `continue` は破棄される。
  - hooks#precompact
  - hooks#exit-code-2-behavior-per-event
- PreCompact が `additionalContext` を返して要約やその後の文脈に影響させられるという記述は無い（`additionalContext` を受け付けるイベントの一覧に PreCompact は含まれない）。要約指示を書き換える出力フィールドも記載なし。
  - hooks#add-context-for-claude

### PostCompact

- 発火: コンパクション完了後。matcher は PreCompact と同じ `manual` / `auto`。
  - hooks#postcompact
- 入力: 共通項目に加えて `trigger` と `compact_summary`（生成された要約本文）。
  ```json
  {"session_id":"abc123","transcript_path":"...jsonl","cwd":"...","hook_event_name":"PostCompact","trigger":"manual","compact_summary":"Summary of the compacted conversation..."}
  ```
  - hooks#postcompact-input
- 出力: decision control なし。コンパクション結果には影響できず、後続処理（要約のログ、外部状態の更新）に使う。`systemMessage` と `continue` は破棄。exit 2 は stderr をユーザーに見せるだけ。
  - hooks#postcompact
  - hooks#decision-control
- PostCompact から Claude のコンテキストへ文を足す手段（`additionalContext` 等）の記載は無い。

### SessionStart（source = compact）

- matcher `compact` は「自動または手動のコンパクション」の後に発火。他に `startup` / `resume` / `clear` / `fork`。
  - hooks#sessionstart
- 入力: 共通項目＋`source`（`"compact"` など）、任意で `model`（省略されることがある）、`agent_type`、`session_title`。`resume` / `fork` のときだけ追加で `seconds_since_last_response`、`context_tokens`、`prompt_cache_likely_expired`、`estimated_cache_write_usd`。
  - hooks#sessionstart-input
- 出力: `hookSpecificOutput.additionalContext`（会話の先頭、最初のプロンプトの前に入る）、`initialUserMessage`（`-p` のみ）、`sessionTitle`（`startup`/`resume`/`fork` のときのみ適用）、`watchPaths`、`reloadSkills`。JSON を組まずに **プレーンテキストの stdout をそのままコンテキストに足せる**（SessionStart、UserPromptSubmit、UserPromptExpansion、PostModelSwitch の 4 イベントだけの特例）。
  - hooks#sessionstart-decision-control
  - hooks#exit-code-0
- `CLAUDE_ENV_FILE` に `export` を追記すると、以後の Bash コマンドに環境変数を引き継げる。
  - hooks#persist-environment-variables
- 公式レシピ「Re-inject context after compaction」: `SessionStart` に `"matcher": "compact"` の command フックを置き、stdout にリマインダを出す。`echo` の代わりに `git log --oneline -5` のような動的出力も使える。
  ```json
  {"hooks":{"SessionStart":[{"matcher":"compact","hooks":[{"type":"command","command":"echo 'Reminder: use Bun, not npm. ...'"}]}]}}
  ```
  - https://code.claude.com/docs/en/hooks-guide#re-inject-context-after-compaction
- context-window ページの表でも「`compact` source に一致する SessionStart フックは実行され、その出力がコンパクション後のコンテキストに足される」と明記。
  - https://code.claude.com/docs/en/context-window#what-survives-compaction
- SessionStart は毎セッション走るので速く保つこと。
  - hooks#sessionstart
- コンパクション後の SessionStart では `mcp_tool` フックも動く（起動時は MCP 未接続のためスキップされる）。
  - hooks（mcp_tool hook fields の節）

### additionalContext / stdout の制約（再注入文を書くときに効く）

- `additionalContext`、`systemMessage`、`initialUserMessage`、プレーン stdout はそれぞれ 10,000 文字が上限。超えるとセッションディレクトリのファイルに保存され、パスと先頭 2,000 文字のプレビューに置き換わる。Claude Code は Claude にそのファイルを読むよう促さないので、必ず見せたい内容は上限内に収める。この上限を上げる設定は無い。
  - hooks#json-output
  - hooks#add-context-for-claude
- `additionalContext` は system reminder に包まれて挿入され、チャット欄には表示されない。
  - hooks#add-context-for-claude
- 文面は命令調のシステム指示ではなく事実の記述で書くよう推奨（例 "The deployment target is production"）。帯域外のシステム命令に見える文は Claude のプロンプトインジェクション防御を誘発し、文脈として扱われずユーザーに提示されることがある。`<system-reminder>` タグを含めると `<` が `&lt;` に置換される。
  - hooks#add-context-for-claude
- 過去にフックが足した文脈は、コンパクション時に会話の他の部分と一緒に要約される。
  - https://code.claude.com/docs/en/context-window#what-survives-compaction
- stdout に JSON 以外（シェルプロファイルの echo など）が混ざると JSON として読まれない。
  - hooks#json-output

### InstructionsLoaded（観測用）

- CLAUDE.md や `.claude/rules/*.md` が読み込まれたときに発火。`load_reason` に `"compact"` があり、コンパクション後に指示ファイルが再読込されたときに使われる。ブロック・決定制御なし、非同期。
  - hooks#instructionsloaded

### スキルの frontmatter に書くフック

- スキルの `hooks` frontmatter で定義したフックは、スキルが呼ばれた時点で登録され、セッションの残り期間ずっと動く。`once: true` で初回成功後に外せる。
  - hooks#hooks-in-skills-and-agents
  - https://code.claude.com/docs/en/skills#frontmatter-reference
- ただし、スキル経由で登録した `SessionStart`（matcher `compact`）や `PreCompact` が実際に発火するかは、ページに個別の記述が無く未確認。

---

## 3. コンパクション後に何が残り、何が再注入されるか

出典: https://code.claude.com/docs/en/context-window#what-survives-compaction （表をそのまま要約）

| 仕組み | コンパクション後 |
| :- | :- |
| システムプロンプト、output style | そのまま有効 |
| プロジェクトルートの CLAUDE.md、paths 指定なしの rules | ディスクから再注入 |
| auto memory（MEMORY.md） | ディスクから再注入 |
| スキルの説明一覧 | 現在のスキルから再構築して再注入（v2.1.304 以降） |
| git status スナップショット | 開始時にあった場合は新しいものを読み直す |
| plan mode で書いた計画 | ディスクから再注入 |
| `paths:` 付き rules、サブディレクトリの CLAUDE.md | 必要時に再読込（会話履歴に入っていた分は要約で消える） |
| Claude が読んだ／編集したファイル | 最近更新されたものから最大 5 件を読み直す。5,000 トークン超のファイルは中身なしのパス参照（`Referenced file`）になる |
| 呼び出したスキル本体 | 1 スキルあたり先頭 5,000 トークン、合計 25,000 トークンまで再注入。古いものから落ちる |
| バックグラウンドのコマンド・サブエージェント | 動き続ける。重複起動しないよう Claude にリマインドされる |
| フックが以前足した文脈 | 会話と一緒に要約される |
| `compact` に一致する SessionStart フック | 実行され、出力がコンパクション後の文脈に足される |

補足:

- CLAUDE.md: 「プロジェクトルートの CLAUDE.md はコンパクションを生き残る。`/compact` の後、ディスクから読み直して再注入する」。指示が消えたなら、それは会話中だけで与えた指示か、まだ再読込されていない nested CLAUDE.md か、まだ一致していない path-scoped rule である。
  - https://code.claude.com/docs/en/memory#instructions-seem-lost-after-compact （見出し "Instructions seem lost after /compact"）
- auto memory: `~/.claude/projects/<project>/memory/`。`MEMORY.md` の先頭 200 行または 25KB（先に達した方）が毎会話の開始時に読み込まれる。トピックファイルは必要時に読む。
  - https://code.claude.com/docs/en/memory
- タスクリスト（Claude の to-do チェックリスト）は「コンパクションをまたいで保持される」。`CLAUDE_CODE_TASK_LIST_ID` で `~/.claude/tasks/` 下の名前付きディレクトリを使い、セッション間で共有できる。タスク系ツールが既定で提供されるのは Opus 4.7、Sonnet 4.6、Haiku 4.5 以前のモデルで、それ以外のモデルでは `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` が必要。
  - https://code.claude.com/docs/en/interactive-mode#task-list
  - https://code.claude.com/docs/en/env-vars
- サブエージェントは独立したコンテキストを持ち、要約だけが戻る。fork は会話のコピーから始まる。
  - https://code.claude.com/docs/en/how-claude-code-works#manage-context-with-skills-and-subagents

---

## 4. Skill の仕様

### 置き場所と呼び出し

- 個人スキル: `~/.claude/skills/<skill-name>/SKILL.md`（そのマシンの全プロジェクト。Cowork・クラウドセッションでは読まれない）。プロジェクトスキル: `.claude/skills/<skill-name>/SKILL.md`。
  - https://code.claude.com/docs/en/skills
- `/skill-name` で直接呼べる。`name`（無ければディレクトリ名）がコマンド名になる。メッセージの先頭に名前を置くと実行され、文中に書いた場合は実行の許可になるだけで実行はされない。
  - https://code.claude.com/docs/en/skills#control-who-invokes-a-skill

### frontmatter（Claude Code で現行有効なキー）

出典: https://code.claude.com/docs/en/skills#frontmatter-reference 。すべて任意、`description` のみ推奨。未知のキーはエラーなしで無視される。

- `name`: `/` メニューに出るコマンド名。既定はディレクトリ名。
- `description`: 何をするか、いつ使うか。`when_to_use` と合わせてスキル一覧では 1,536 文字で切られるので、主用途を先に書く。
- `when_to_use`: 起動条件の追加説明。`description` に連結され、1,536 文字の上限に数えられる。
- `argument-hint`: 補完時に出す引数のヒント（例 `[issue-number]`）。
- `arguments`: `$name` 置換用の名前付き位置引数。
- `disable-model-invocation`: `true` で Claude の自動起動を禁止し、`/name` からの手動起動専用にする。説明文もコンテキストに入らない（呼ぶまでコストゼロ）。サブエージェントへのプリロードや、スキルを prompt にしたスケジュールタスクでの実行も止まる。
- `user-invocable`: `false` で `/` メニューから隠し、Claude だけが呼べるようにする。
- `allowed-tools`: そのスキルを呼んだターンの間だけ、許可なしで使えるツール。次のメッセージを送ると解除される（スキル本文は文脈に残るが許可は残らない）。
- `disallowed-tools`: スキル有効中に使えなくするツール。
- `model` / `effort`: そのターンのモデル・effort を上書き。
- `context: fork` / `agent` / `background`: フォークしたサブエージェントで実行。
- `hooks`: 呼び出し時に登録し、セッション終了まで有効なフック。
- `paths`: 自動起動を特定のファイルパターンに限定。
- `shell`: `!` ブロックのシェル（`bash` 既定 / `powershell`）。
- `metadata` / `license` / `compatibility`: Claude Code は動作に使わない。

API／Agent Skills 側の制約（Claude Code 以外でも使う場合）:

- `name` は最大 64 文字、小文字・数字・ハイフンのみ、XML タグ不可、"anthropic"・"claude" を含めない。`description` は空不可、最大 1,024 文字、XML タグ不可。説明は三人称で書く。
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#skill-structure

### 文字列置換と動的コンテキスト注入

- `$ARGUMENTS`、`$ARGUMENTS[N]`、`$N`、`$name`、`${CLAUDE_SESSION_ID}`（セッション固有ファイルの命名に使える）、`${CLAUDE_SKILL_DIR}`（SKILL.md のあるディレクトリ）、`${CLAUDE_PROJECT_DIR}`、`${CLAUDE_EFFORT}` など。
  - https://code.claude.com/docs/en/skills#available-string-substitutions
- `` !`<command>` `` はスキル本文を Claude に渡す前にシェルを実行し、出力で置き換える。複数行は ` ```! ` ブロック。置換は 1 回だけで再走査されない。コマンドが失敗するとスキル起動全体が中止される。
  - https://code.claude.com/docs/en/skills （"Dynamic context injection" / "Inject dynamic context"）

### progressive disclosure と分量

- スキルは 3 段階で読み込まれる: メタデータ（name・description、起動時に常時）、SKILL.md 本文（関連時）、追加ファイル（必要時）。
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#how-skills-work
  - https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills （2025-10-16）
- SKILL.md は 500 行未満に保ち、詳細は別ファイルへ。補助ファイルは SKILL.md から参照し、各ファイルの中身と読むべき場面を書く。
  - https://code.claude.com/docs/en/skills#add-supporting-files
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#progressive-disclosure-patterns
- 参照は SKILL.md から 1 階層までにする（入れ子にすると部分読みしかされないことがある）。100 行を超える参照ファイルには先頭に目次を置く。パスはスラッシュ区切り。
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- 複雑な手順は順序付きステップとチェックリストにし、検証→修正→再検証のフィードバックループを入れる。
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#workflows-and-feedback-loops
- 「Claude は既に賢い」前提で、Claude が知らない情報だけを書く。
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#concise-is-key

### スキル本文のライフサイクルとコンパクション

- 呼び出されたスキルの本文は 1 つのメッセージとして会話に入り、以後のターンでも残る。Claude Code は以後のターンでスキルファイルを読み直さないので、タスク全体に効かせたい内容は一回限りの手順ではなく常設の指示として書く。
  - https://code.claude.com/docs/en/skills#skill-content-lifecycle
- 同一内容での再呼び出しは「already loaded」の短い注記になる。引数や `!` コマンドの出力が変われば全文が再追加される。
  - https://code.claude.com/docs/en/skills#skill-content-lifecycle
- 自動コンパクション時、各スキルの最新の呼び出しを要約の後に再添付する。1 スキル先頭 5,000 トークン、合計 25,000 トークン、最近呼んだものから埋める。切り詰めはファイル先頭を残すので、重要な指示は SKILL.md の上の方に置く。
  - https://code.claude.com/docs/en/skills#skill-content-lifecycle
  - https://code.claude.com/docs/en/context-window#what-survives-compaction
- コンパクション後にスキルに従わなくなったら、スキルを再度呼べば全文が戻る。毎回必ず守らせたい規則はフックに移す（スキルの `hooks` frontmatter に置けばスキルと一緒に管理できる）。
  - https://code.claude.com/docs/en/skills#claude-stops-following-a-skill
- 手動専用の指示を CLAUDE.md からスキルへ移すと基本コンテキストが小さくなる。CLAUDE.md は 200 行未満が目安。
  - https://code.claude.com/docs/en/costs#move-instructions-from-claude-md-to-skills
  - https://code.claude.com/docs/en/memory

---

## 5. Claude API 側のコンテキスト管理

### サーバー側コンパクション（compaction API）

- 古いターンをサーバー側で Claude が書いた要約に置き換える。方式は 3 つ: on-demand（ベータ `compact-2026-09-04`、トップレベル `compaction` パラメータ。アプリが要約のタイミングを決める）、トークン閾値（ベータ `compact-2026-01-12`、`context_management.edits` に `compact_20260112`）、自前の要約器。利用可能なら on-demand を推奨。
  - https://platform.claude.com/docs/en/build-with-claude/compaction
- on-demand: 応答は `compaction` ブロック 1 つ（要約テキストと署名）。以後はそのブロックを `messages` の先頭に置き、要約されたメッセージを取り除く。`instructions`（最大 16,384 文字）で既定の要約プロンプトを丸ごと置き換えられる。指示では「何を残すか」と「ツールを呼ばないこと」を書く。
  - https://platform.claude.com/docs/en/build-with-claude/compaction-on-demand
- 閾値方式: `trigger` 既定 `{"type":"input_tokens","value":150000}`（最小 50,000）、`pause_after_compaction`、`instructions`（既定プロンプトを完全に置き換える）。
  - https://platform.claude.com/docs/en/build-with-claude/compaction-threshold
- 直近ターンを逐語で残す派生（keep recent turns）、バックグラウンド実行もある。
  - https://platform.claude.com/docs/en/build-with-claude/compaction

### Context editing（`context-management-2025-06-27`）

- 多くの用途ではサーバー側コンパクションが主戦略で、context editing はより細かい制御が必要な場合向け、と明記。
  - https://platform.claude.com/docs/en/build-with-claude/context-editing#overview
- `clear_tool_uses_20250919`: 閾値を超えたら古いツール結果から順に消し、プレースホルダに置き換える。設定: `trigger`（既定 100,000 input tokens）、`keep`（既定 3 ツール使用）、`clear_at_least`、`exclude_tools`、`clear_tool_inputs`（既定 false）。消すとキャッシュ済みプレフィクスが無効になる。
  - https://platform.claude.com/docs/en/build-with-claude/context-editing#configuration-options-for-tool-result-clearing
- `clear_thinking_20251015`: 過去ターンの thinking ブロックを管理。
- memory tool と併用すると、閾値に近づいた時点で Claude に自動警告が出て、消される前に重要情報をメモリファイルへ書き出せる。
  - https://platform.claude.com/docs/en/build-with-claude/context-editing#using-with-the-memory-tool
- Client-side SDK compaction（TypeScript / Ruby SDK の `tool_runner`）の既定要約プロンプトは公開されており、次の 5 項目を求める: 1) Task Overview（中心となる要求、成功条件、制約）、2) Current State（完了事項、作成・変更・分析したファイル、成果物）、3) Important Discoveries（技術的制約、決定とその理由、遭遇したエラーと解決、うまくいかなかった方法とその理由）、4) Next Steps（具体的な次の行動、ブロッカー・未解決の問い、優先順位）、5) Context to Preserve（ユーザーの好み、自明でないドメイン固有の詳細、ユーザーへの約束）。`<summary></summary>` で囲む。
  - https://platform.claude.com/docs/en/build-with-claude/context-editing#default-summary-prompt

### Memory tool

- クライアント側で実装するファイル操作ツール（`/memories` 配下、view / create / str_replace / insert / delete / rename）。just-in-time の文脈取得を支える。
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
- memory tool を有効にすると API が自動でシステムプロンプトに次を足す: 「ALWAYS VIEW YOUR MEMORY DIRECTORY BEFORE DOING ANYTHING ELSE. ... As you make progress, record status / progress / thoughts etc in your memory. ASSUME INTERRUPTION: Your context window might be reset at any moment, so you risk losing any progress that is not recorded in your memory directory.」
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool#prompting-guidance
- コンパクションとの併用: コンパクションはクライアント側の管理なしに文脈を小さく保ち、メモリは要約を生き残るべき情報を保持する。
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool#using-with-compaction
- Multisession software development pattern: 初回セッションで進捗ログ（済んだこと・次にやること）、機能チェックリスト（作業範囲）、起動スクリプトへの参照を作る。以後のセッションは最初にそれらを読む。終了前に進捗ログを更新する。一度に 1 機能、エンドツーエンド検証後にだけ完了にする。
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool#multisession-software-development-pattern
- Context awareness（`<budget:token_budget>` と各ツール呼び出し後の残量通知）は Sonnet 5 / Sonnet 4.6 / Sonnet 4.5 / Haiku 4.5 のみ。Opus 4.7 以降の Opus、Sonnet 5.5、Fable、Haiku 5.5 には注入されない（task budgets ベータで代替）。複数セッションにまたがるエージェントでは、新セッション開始時の文脈復元が速くなるよう状態ファイルを設計するよう勧めている。
  - https://platform.claude.com/docs/en/build-with-claude/context-windows#context-awareness

---

## 6. エンジニアリングブログの知見

### Effective context engineering for AI agents（2025-09-29）

https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

- 目標は「望む結果の確率を最大化する、最小の高シグナルなトークン集合」。トークンが増えるほど想起精度が落ちる（context rot、attention budget）。
- just-in-time: ファイルパスや保存済みクエリなど軽量な識別子を持ち、実行時にツールで読み込む。
- 長期タスクの 3 手法:
  - コンパクション: Claude Code ではアーキテクチャ上の決定、未解決のバグ、実装の詳細を残し、圧縮した文脈と直近にアクセスした 5 ファイルで続行する。最も軽い形はツール結果のクリア。
  - 構造化ノート: コンテキストの外にノートを定期的に書く（Claude Code の to-do リスト、`NOTES.md`）。Pokémon の例では「直近 1,234 ステップで Route 1 で訓練し、Pikachu は目標 10 のうち 8 レベル上がった」のような定量的な進捗を残す。
  - サブエージェント: 凝縮した要約（1,000〜2,000 トークン程度）だけを返す。
- 使い分け: コンパクションはやり取りの多いタスクの流れの維持、ノートは明確なマイルストーンのある反復開発、マルチエージェントは並列探索が効く調査。

### Effective harnesses for long-running agents（2025-11-26）

https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

- 「compaction isn't sufficient」。高レベルのプロンプトだけでは一度にやり過ぎる、途中で完了宣言する、という失敗が出た。
- 初期化エージェント（初回のみ環境を整える）とコーディングエージェント（毎セッション少しずつ進める）の 2 段構成。
- 成果物: `init.sh`（開発サーバ起動）、`claude-progress.txt`（エージェントが行ったことのログ）、JSON の機能リスト（`passes` フィールドだけを変更させる。JSON はモデルが不適切に書き換えにくい）、説明的なメッセージ付きの git コミット。
- 各セッションの立ち上げ手順: 1) `pwd`、2) git log と進捗ファイルを読む、3) 機能リストから未完で優先度最高のものを 1 つ選ぶ、4) `init.sh` を実行し、新機能の前に基本的な E2E テストを通す。
- 1 回に 1 機能。終了時はマージ可能なクリーンな状態にし、コミットと進捗更新で終える。テスト後にだけ "passing" にする。

### Harness design for long-running application development（2026-03-24）

https://www.anthropic.com/engineering/harness-design-long-running-apps

- コンパクション（その場で要約）とコンテキストリセット（新しいエージェントで白紙から開始）を区別。リセットは、引き継ぎ成果物に十分な状態が含まれていることが前提。
- 「context anxiety」: 上限が近いと思うと作業を早く畳む挙動。Sonnet 4.5 ではコンパクションだけでは足りず、前のエージェントの状態と次のステップを持つ構造化ハンドオフ付きのリセットが必要だった。
- Opus 4.5 でこの挙動がほぼ消え、後のハーネスではリセットを外し、自動コンパクション付きの 1 本の連続セッションで動かした。
- エージェント間の通信はファイル経由。スプリント前に「完了」の定義を合意する（sprint contract）。

### Building agents with the Claude Agent SDK（2025-09-29、claude.com/blog）

https://www.claude.com/blog/building-agents-with-the-claude-agent-sdk

- ファイルシステムは文脈に引き込める情報の置き場であり、フォルダ構成そのものがコンテキストエンジニアリングになる。
- SDK の compact 機能は上限に近づくと過去のメッセージを自動要約する。サブエージェントは独立したコンテキストで動き、必要な情報だけを返す。
- エージェントループ: gather context → take action → verify work → repeat。

### その他（関連度低）

- An update on recent Claude Code quality reports（2026-04-23）: 1 時間以上アイドルだったセッションの古い thinking を消す変更（2026-03-26）が、毎ターン消すバグになっていた（04-10 修正）。コンパクションへの言及は無い。
  - https://www.anthropic.com/engineering/april-23-postmortem

---

## 7. プロンプトガイドの推奨（コンテキストウィンドウをまたぐ状態管理）

出典: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices （Fable 5.1 / Opus 5.5 / Sonnet 5.5 / Haiku 5.5 などの現行モデル対象）

### Long-horizon reasoning and state tracking

- コンパクションや外部ファイルへの保存ができるハーネス（Claude Code など）では、それをプロンプトで伝えると、上限が近づいても作業を早く畳まない。例文: 「Your context window will be automatically compacted as it approaches its limit ... As you approach your token budget limit, save your current progress and state to memory before the context window refreshes. ...」
- 複数ウィンドウにまたがるタスク:
  1. 最初のウィンドウは枠組み作り（テスト、セットアップスクリプト）、以後は to-do リストを回す。
  2. テストを構造化形式（`tests.json`）で管理し、「テストを消したり編集したりするのは許されない」と伝える。
  3. `init.sh` などの QOL スクリプトを作らせる。
  4. 新しいウィンドウで始める場合、コンパクションより白紙から始めた方がよいこともある。最新モデルはローカルファイルシステムから状態を見つけるのが得意。開始手順を具体的に指示する: 「Call pwd」「Review progress.txt, tests.json, and the git logs.」「新機能の前に基本的な統合テストを手で通す」。
  5. 検証手段を与える。
  6. 未コミットの大きな作業を残したまま文脈を使い切らないよう促す。
- 状態管理のベストプラクティス: 構造化データ（テスト結果、タスク状態）は JSON 等、進捗メモは自由記述テキスト、git をログとチェックポイントに使う、段階的な進捗を明示的に求める。例として `tests.json`（id・name・status と集計）と `progress.txt`（「Session 3 progress: ... Next: ... Note: Do not remove tests ...」）を掲載。

### モデル別ページの関連項目

- Fable 5.1「Tell the model what to preserve in compaction summaries」: クライアント側でコンパクションする場合の要約指示の例。残すべきもの: (1) 起きた問題と対処、(2) 出た選択肢・試した方法・却下したものとその理由、(3) 依頼・決定・合意・除外・好み・制約・境界（正確に）、(4) 現在地（何が済み・確定したか）、(5) 未解決・約束・次に起きること、(6) 再構成が難しい具体（名前、数値、日付、正確な文言、リンク）。ユーザーの発言は原文に近く、モデル自身の説明や推論は結論まで圧縮する。
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1#tell-the-model-what-to-preserve-in-compaction-summaries
- Fable 5.1「Finish the whole task」: 「Do not stop because the context or session is long.」を含む自律実行向けの追加文。
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1#finish-the-whole-task
- Fable 5「Ground progress claims during long runs」: 進捗報告の各主張をこのセッションのツール結果と照合し、未検証なら明示させる。「Construct a memory system」: 1 ファイル 1 教訓、先頭に 1 行要約、リポジトリやチャット履歴に既にあるものは書かない、重複せず既存を更新、誤りと判明したら削除。
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- Opus 5.5「Unattended agentic runs」: テキストだけのターン終了を完了の証拠と扱わず、タスクの各部分を to-do ツールやファイルのチェックリストで管理し、未完項目が残っていれば短いユーザーメッセージで続行させる（自動継続は 2〜3 回まで）。
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5#unattended-agentic-runs
- 内部推論を応答テキストに書き写させる指示は `reasoning_extraction` で拒否されうる（Fable 5 / Opus 5.5）。行った操作の要約や結論の説明は求めてよい。
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5#safeguard-refusals
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5

---

## 8. 未確認事項

- PreCompact フックが `additionalContext` 等で要約内容やコンパクション後の文脈に文を足せるか: ドキュメント上は不可（記載なし）。要約指示（`custom_instructions`）をフックから書き換える手段も記載なし。
- PostCompact フックから Claude の文脈へ文を足す手段: 記載なし。
- スキルの `hooks` frontmatter で登録した SessionStart(`compact`) / PreCompact / PostCompact が発火するか: 個別の記述なし。
- CLAUDE.md の "Compact Instructions" が特別に解析されるのか、通常の CLAUDE.md 本文として要約時に参照されるだけなのか: 記載なし。見出しの綴りもページで揺れている。
- Claude Code の要約プロンプト全文: 非公開（API の client-side SDK 用の既定プロンプトのみ公開）。
- コンパクション後に「読み直す最大 5 ファイル」の選定に、直前に編集した記録ファイルが確実に含まれるか: 「最近更新されたものから」とあるが、他のファイル更新との順序次第で、確実とは書かれていない。
- タスクリストがコンパクション後にどう提示されるか（全文再注入か参照か）: 「persist across context compactions」以上の記述なし。
- docs.claude.com の旧 URL から現行ページへのリダイレクト: 確認していない（本調査は code.claude.com / platform.claude.com を直接読んだ）。

---

## 9. /refresh 設計への含意

### 使えるフックと役割分担

- **SessionStart(matcher `compact`) が復帰の主経路**。プレーン stdout がそのままコンパクション後の文脈に入る唯一の公式手段であり、公式レシピもこれを使う。記録ファイルの要点（現在のタスク、次の一手、記録ファイルのパス）を出力するスクリプトを置く。
  - 出力は 10,000 文字未満に収める（超えるとファイル退避＋2,000 文字プレビューになり、Claude は読むよう促されない）。
  - 文面は命令ではなく事実の記述にする（「Current task: ...」「Record file: /path/...」）。命令調はインジェクション防御に引っかかる。
  - 速く終わる処理だけにする（`cat` / `head` / `git log --oneline -5` 程度）。
  - `type` は `command`（または `mcp_tool`）のみ可。
- **PreCompact は「書き出しの最後の機会」だが Claude に書かせることはできない**。コマンドフックとして、トランスクリプト（`transcript_path`）のコピーや、記録ファイルのタイムスタンプ確認などの機械的処理に限る。記録が古すぎるときに exit 2 / `decision: "block"` で止める設計は可能だが、上限エラー回復目的の自動コンパクションを止めるとリクエストが失敗するので、ブロックは `manual` に限定するのが安全。
- **PostCompact は監査ログ用**。`compact_summary` を記録ディレクトリに保存しておけば、要約が何を落としたかを後で比較できる。Claude の文脈は変えられない。
- フックの登録先は `~/.claude/settings.json`（全プロジェクト）か `.claude/settings.json`。スキルの `hooks` frontmatter 経由の SessionStart 発火は未確認なので、確実性が要るなら settings に置く。設定作業は update-config スキルの範囲。

### Skill 本体（SKILL.md）の書き方

- `disable-model-invocation: true` にすると説明文がコンテキストに載らず、`/refresh` での手動起動専用になる。Claude に上限前の自動書き出しもさせたいなら `false` のままにし、`description` 冒頭に「コンテキストが大きくなった／コンパクション前後」などの起動条件を書く（1,536 文字上限）。
- `argument-hint` で `[save|resume]` のようなモードを示し、`$ARGUMENTS` で分岐できる。
- `${CLAUDE_SESSION_ID}` で記録ファイルをセッション単位に分けられる。`` !`git status --short` `` や `` !`git log --oneline -10` `` を本文に埋めれば、起動時点の状態を Claude に渡せる（コマンド失敗でスキル全体が中止されるので `|| true` を付ける）。
- **復帰手順は SKILL.md の先頭に置く**。コンパクション後に再添付されるのは先頭 5,000 トークンだけで、他のスキルと合計 25,000 トークンを分け合う。手順の詳細やテンプレートは `references/` に分け、SKILL.md から 1 階層で参照する（500 行未満）。
- スキル本文は以後のターンで読み直されないので、「作業中は節目ごとに記録を更新する」のような常設の指示として書く。
- `allowed-tools` は起動したターンだけ有効。記録ファイルへの Write/Edit を毎回許可なしで行わせたいなら、permissions の allow ルールで別途許可する。

### 記録ファイルに書くべき内容

公式の要約プロンプト（API の既定プロンプト、Fable 5.1 の推奨指示）と長時間ハーネスの成果物を突き合わせると、次の項目が共通している。

- タスクの概要: 元の依頼、成功条件、ユーザーが指定した制約・好み・境界（ユーザーの言葉に近い形で）。
- 現在地: 完了したこと、変更したファイル（パス付き）、生成した成果物。
- 決定とその理由、試して捨てた方法とその理由、発生したエラーと解決。
- 次の一手（具体的な行動、優先順位）、ブロッカー、未解決の問い、ユーザーへの約束。
- 再構成が難しい具体: 名前、数値、コマンド、URL、正確な文言。
- 検証状態: 各項目が「検証済み（どのコマンド・テストで）」か「未検証」かを区別する（Fable 5 の progress claims の推奨）。
- 形式の使い分け: タスク／テストの状態は JSON（チェックリスト、`passes` / `status` だけを書き換える）、経緯は自由記述テキスト。履歴とチェックポイントは git に任せる。
- 書かないもの: リポジトリや git log から分かること、内部推論の書き写し（`reasoning_extraction` 拒否の対象になりうる。結論と根拠だけ残す）。
- サイズ: SessionStart で注入する要約部分は 10,000 文字未満。ファイル全体も 5,000 トークン未満に抑えれば、コンパクション後の「最近更新したファイル最大 5 件の読み直し」で中身付きで戻る可能性がある（確実ではない）。

### 永続化の置き場所の使い分け

- 常に守るルール → プロジェクトルートの CLAUDE.md（コンパクション後にディスクから再注入される）。`paths:` 付き rules や nested CLAUDE.md は要約で消えうる。
- セッションをまたいで残すべき教訓 → auto memory（MEMORY.md は先頭 200 行／25KB まで）。
- 進行中タスクの状態 → /refresh の記録ファイル（＋git）。タスクリストもコンパクションをまたいで保持されるので、Claude Code がタスクツールを提供するモデルでは併用できる。
- CLAUDE.md に Compact Instructions 節を足し、「記録ファイルのパスと次の一手を要約に必ず残す」と書いておくと、要約にポインタが残る（仕組みの詳細は未確認だが、公式に推奨された手段）。

### コンパクション後の復帰手順（SKILL.md 先頭に置く想定）

1. SessionStart(`compact`) の注入文、または `/refresh resume` で記録ファイルのパスを得る。
2. `pwd` で作業ディレクトリを確認する。
3. 記録ファイル（進捗メモ、タスク JSON）を読む。
4. `git log --oneline -n` と `git status` で、記録後に何が変わったかを照合する。記録とリポジトリが食い違えばリポジトリを正とし、記録を更新する。
5. 記録の「次の一手」と未検証項目を確認し、必要なら基本テストを 1 回通してから作業を再開する。
6. 呼び出していたスキルの指示に従っていないと気づいたら、そのスキルを再度呼ぶ（全文が戻る）。

### 書き出しのタイミング

- 手動: `/compact` の前に `/refresh`（save）を実行し、続けて `/compact <記録ファイルを参照する旨の指示>` を打つ運用が最も確実（PreCompact は Claude に書かせられないため）。
- 自動: 自動コンパクションのタイミングは Claude から事前に分からない。API の context awareness（残量通知）も Opus 4.7 以降などには注入されない（Claude Code 内で残量が Claude に伝わるかは未確認）。したがって「節目（1 機能完了、方針決定、コミット）ごとに記録を更新する」常設指示で備え、SessionStart(`compact`) で拾う設計にする。プロンプトガイドの例文どおり、コンパクションがあることを Claude に伝えて早期終了を防ぐ文言も入れられる。
- アイドルコンパクション（約 54 分無操作、200K 以上）も `auto` として発火するので、離席前に `/refresh` で保存しておくと復帰が安定する。
