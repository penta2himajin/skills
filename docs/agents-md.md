# AGENTS.md の調査メモ（複数エージェントで共有するグローバル指示ファイル）

調査日: 2026-10-26。一次情報（公式ドキュメント、公式リポジトリのソースコード、agents.md のサイトとそのリポジトリ）だけを根拠にした。各主張には出典を付けた。一次情報で確認できなかった事項は「未確認」と書いた。

この文書は [`examples/AGENTS.example.md`](../examples/AGENTS.example.md) を、Claude Code の `~/.claude/CLAUDE.md` 向けの例から、複数のコーディングエージェントが共有するユーザー単位（グローバル）の AGENTS.md の例へ書き換えるための下調べである。

参照したリポジトリの版:

- agentsmd/agents.md: `main` の [d001185](https://github.com/agentsmd/agents.md/tree/d001185d792eb6402a58e4cbef1c228b309ec25d)（2026-09-10）
- openai/codex: `main` の [970111f](https://github.com/openai/codex/tree/970111f6cb62cc02fe36a82ea7d71b37a2889c97)（2026-10-23）
- google-gemini/gemini-cli: `main` の [cd1b45c](https://github.com/google-gemini/gemini-cli/tree/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005)（2026-10-23）
- anomalyco/opencode（旧 sst/opencode）: リリース [v1.19.4](https://github.com/anomalyco/opencode/tree/v1.19.4)（2026-10-22）と `dev` のドキュメント
- agentskills/agentskills: `main`（2026-08-09 更新）
- Claude Code のドキュメントは code.claude.com の 2026-10-26 時点の版。手元の Claude Code は v2.1.310。

## 1. AGENTS.md という規約そのもの

AGENTS.md は「コーディングエージェント向けの README」と位置づけられた、単純な Markdown ファイルの規約である（[agents.md のトップ](https://agents.md/)、[Hero.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/Hero.tsx)）。運営は Linux Foundation 傘下の Agentic AI Foundation に移っている（[AboutSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/AboutSection.tsx)）。

- 形式: 必須の項目はない。「AGENTS.md is just standard Markdown. Use any headings you like」と書かれている（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。正式な仕様書（RFC 形式の文書やスキーマ）は、サイトのリポジトリには存在しない。リポジトリにあるのはサイトの Next.js ソース、README、憲章 PDF だけである（[リポジトリのツリー](https://github.com/agentsmd/agents.md/tree/d001185d792eb6402a58e4cbef1c228b309ec25d)）。
- 置き場所: 「Create an AGENTS.md file at the root of the repository」（[HowToUseSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/HowToUseSection.tsx)）。規約が定めるのはリポジトリ内の置き場所だけで、ユーザー単位（ホームディレクトリ）のグローバルファイルについては何も書かれていない（同ファイル、[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)、[README.md](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/README.md) を確認）。グローバルファイルのパスは各エージェントの独自仕様である（第 2 節）。
- 入れ子とモノレポ: 「Place another AGENTS.md inside each package. Agents automatically read the nearest file in the directory tree, so the closest one takes precedence」（[HowToUseSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/HowToUseSection.tsx)）。衝突時は「The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.」（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。ただし実装はこの記述と一致しない。Codex や Claude Code は近いファイルだけを読むのではなく、ルートから作業ディレクトリまでの各ファイルを連結する（第 2 節）。
- 推奨する内容: プロジェクト概要、ビルドとテストのコマンド、コードスタイル、テストの手順、セキュリティ上の注意。加えてコミットメッセージや PR の規約、デプロイ手順など「anything you'd tell a new teammate」（[HowToUseSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/HowToUseSection.tsx)）。
- 取り込み（import）構文: 規約には定義がない（上記の全ファイルを確認）。
- 長さ: 規約には長さの目安がない（上記の全ファイルを確認）。長さの目安は各エージェントの文書にある（第 4 節）。
- 既存ファイルからの移行: 「Rename existing files to AGENTS.md and create symbolic links for backward compatibility」として `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` を示す（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。
- 対応エージェントの一覧: Codex、Cursor、Gemini CLI、opencode、GitHub Copilot の coding agent、VS Code、Jules、Amp、Aider、Zed、Warp など 23 件が載っている。Claude Code は一覧にない（[CompatibilitySection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/CompatibilitySection.tsx)）。Aider と Gemini CLI は設定が要るとして、FAQ に設定例がある（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。

## 2. エージェントごとの読み込み場所と優先順位

### 一覧

| エージェント | プロジェクトの AGENTS.md | ユーザー単位（グローバル）の指示ファイル | グローバルな AGENTS.md の正確なパス |
| - | - | - | - |
| Claude Code | 読む（v2.1.277 以降、既定では CLAUDE.md が無いときだけ） | `~/.claude/CLAUDE.md` | なし（文書化されていない） |
| OpenAI Codex CLI | 読む | `~/.codex/AGENTS.override.md` または `~/.codex/AGENTS.md` | `~/.codex/AGENTS.md`（`CODEX_HOME` で変更可） |
| Gemini CLI | 既定では読まない。`context.fileName` に入れれば読む | `~/.gemini/GEMINI.md` | `~/.gemini/AGENTS.md`（`context.fileName` に `AGENTS.md` を入れた場合） |
| Google Antigravity（`agy` を含む） | 読む | `~/.gemini/AGENTS.md` など 4 つ | `~/.gemini/AGENTS.md`（`~/.gemini/config/AGENTS.md` は一部の一覧にだけ載る） |
| OpenCode | 読む | `~/.config/opencode/AGENTS.md`（無ければ `~/.claude/CLAUDE.md`） | `~/.config/opencode/AGENTS.md` |
| Cursor | 読む | 設定画面の User Rules、`~/.cursor/rules` | なし（文書化されていない） |
| GitHub Copilot CLI | 読む | `~/.copilot/copilot-instructions.md` | 固定パスなし。`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` に挙げたディレクトリの `AGENTS.md` |
| VS Code（Copilot） | 読む（`chat.useAgentsMdFile`、既定で有効） | `~/.copilot/copilot-instructions.md`。Local harness で `chat.useClaudeMdFile` を有効にすると `~/.claude/CLAUDE.md` も | なし（文書化されていない） |
| pi coding agent | 読む | `~/.pi/agent/AGENTS.md` など | `~/.pi/agent/AGENTS.md`（`PI_CODING_AGENT_DIR` で変更可） |

各行の根拠は以下の小節に書いた。

### Claude Code

- AGENTS.md を直接読む。ただし v2.1.277 以降で、プロジェクトの指示ファイルとして読む。「Claude Code can read `AGENTS.md` as your project instructions, so a repository already set up for other coding agents works without adding a `CLAUDE.md`, an import, or a setting.」「Reading `AGENTS.md` directly requires Claude Code v2.1.277 or later.」（[memory#agents-md](https://code.claude.com/docs/en/memory#agents-md)）。読み込むのは組み込みプラグイン `cc-plugin-agents-md@builtin`（v2.1.285 より前は `agents-md@builtin`）である（[memory#choose-which-instruction-files-load](https://code.claude.com/docs/en/memory#choose-which-instruction-files-load)）。
- 既定（`claude-md-or-agents-md`）では、作業ディレクトリとその上位に `CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` のどれも無いときだけ AGENTS.md を読む。`~/.claude/CLAUDE.md`、組織の managed CLAUDE.md、`.claude/rules/` はこの判定に数えず、AGENTS.md と一緒に読み込まれる（[memory#when-claude-code-reads-agentsmd](https://code.claude.com/docs/en/memory#when-claude-code-reads-agentsmd)）。`/config` の **Project instructions** を `claude-md-and-agents-md` にすると両方を読む（同ページ [choose-which-instruction-files-load](https://code.claude.com/docs/en/memory#choose-which-instruction-files-load)）。
- 読む場所: セッション開始時に作業ディレクトリと上位ディレクトリの `AGENTS.md` と `.claude/AGENTS.md`。サブディレクトリの AGENTS.md は、Claude がそこにあるファイルを Read ツールで開いたときに読む。`AGENTS.local.md`、`AGENTS.override.md`、`.agents/` 配下は読まない（[memory#when-claude-code-reads-agentsmd](https://code.claude.com/docs/en/memory#when-claude-code-reads-agentsmd)）。
- ユーザー単位のファイルは `~/.claude/CLAUDE.md` である（[memory#choose-where-to-put-claudemd-files](https://code.claude.com/docs/en/memory#choose-where-to-put-claudemd-files)）。ユーザー単位の AGENTS.md（例: `~/.claude/AGENTS.md`）は文書化されていない。[memory](https://code.claude.com/docs/en/memory)、[claude-directory](https://code.claude.com/docs/en/claude-directory)、[glossary](https://code.claude.com/docs/en/glossary) を確認した。どれも AGENTS.md をプロジェクトの指示ファイルとしてだけ扱う。作業ディレクトリがホーム配下にあるとき、上位ディレクトリの走査で `~/AGENTS.md` や `~/.claude/AGENTS.md` が読み込まれるかどうかは未確認（文書に記述がなく、試していない）。
- AGENTS.md を直接読めないセッション: v2.1.277 より前、組み込みプラグインを `/plugin` で無効にしたとき、v2.1.276 以前から更新した直後の最初のセッション。v2.1.281 より前は Amazon Bedrock 経由やテレメトリ無効のセッションも該当した。このときは CLAUDE.md から import するよう案内されている（[memory#when-agents-md-support-is-unavailable](https://code.claude.com/docs/en/memory#when-agents-md-support-is-unavailable)）。
- 読み込み順: 管理ポリシー、ユーザー、プロジェクトの順に連結し、上書きはしない（[memory#how-claudemd-files-load](https://code.claude.com/docs/en/memory#how-claudemd-files-load)）。

### OpenAI Codex CLI

- グローバル: 「In your Codex home directory (defaults to ~/.codex, unless you set CODEX_HOME), Codex reads AGENTS.override.md if it exists. Otherwise, Codex reads AGENTS.md. Codex uses only the first non-empty file at this level.」（[Codex の AGENTS.md ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。旧 URL [developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md) から 308 でここへ転送される）。ソースでも `~/.codex` の直下で `AGENTS.override.md`、`AGENTS.md` の順に探し、空でない最初のファイルを使う（[codex-home/src/instructions/mod.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/codex-home/src/instructions/mod.rs)）。
- プロジェクト: プロジェクトルート（既定では `.git` のあるディレクトリ）から作業ディレクトリまで下り、各ディレクトリで `AGENTS.override.md`、`AGENTS.md`、`project_doc_fallback_filenames` の順に探して 1 ディレクトリにつき 1 ファイルだけ採る。作業ディレクトリより下のディレクトリは読まない（[ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)、[agents_md.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/core/src/agents_md.rs) 冒頭のコメント「We do **not** walk past the project root.」）。
- 優先順位: 「Codex concatenates files from the root down, joining them with blank lines. Files closer to your current directory override earlier guidance because they appear later in the combined prompt.」グローバルのファイルが最初に来る（[ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)）。
- `project_doc_fallback_filenames` はプロジェクトの各ディレクトリの探索にだけ使われる。グローバルの読み込み処理は `AGENTS.override.md` と `AGENTS.md` の 2 つしか見ない（[mod.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/codex-home/src/instructions/mod.rs)）。

### Gemini CLI

- 既定のファイル名は `GEMINI.md` で、AGENTS.md は既定では読まない（[memoryTool.ts](https://github.com/google-gemini/gemini-cli/blob/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005/packages/core/src/tools/memoryTool.ts) の `DEFAULT_CONTEXT_FILENAME = 'GEMINI.md'`）。`settings.json` の `context.fileName` に文字列か配列で名前を指定すると、その名前で探す。公式文書の例は `["AGENTS.md", "CONTEXT.md", "GEMINI.md"]`（[gemini-md.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md)、[configuration.md の context.fileName](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md)）。agents.md の FAQ も同じ設定を案内している（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。
- グローバル: 「`~/.gemini/<configured-context-filename>` (for example, `~/.gemini/GEMINI.md` in your user home directory)」（[configuration.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md)）。ソースでは設定した全てのファイル名について `~/.gemini/<名前>` を調べ、存在するものを全部読む（[memoryDiscovery.ts の getGlobalMemoryPaths](https://github.com/google-gemini/gemini-cli/blob/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005/packages/core/src/utils/memoryDiscovery.ts)）。したがって `context.fileName` に `AGENTS.md` を入れれば `~/.gemini/AGENTS.md` が読まれる。
- 読み込み順: グローバル、作業ディレクトリから上位へ（`.git` かホームまで）、作業ディレクトリ以下のサブディレクトリ（既定で最大 200 ディレクトリ、`context.discoveryMaxDirs`）。ツールがファイルにアクセスしたときにも、その祖先の context ファイルを読む（JIT）。全てを連結し「more specific」なものが後に来る（[gemini-md.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md)、[configuration.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md)）。

### Google Antigravity（App、IDE、CLI `agy`）

- グローバル: 「Standalone global files (no frontmatter needed, always active): `~/.gemini/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.gemini/config/AGENTS.md`, or `~/.gemini/config/GEMINI.md`」。frontmatter 付きの `~/.gemini/config/rules/*.md` も使える。CLI はこれに加えて `~/.gemini/antigravity-cli/rules/*.md` とプラグインの rules を読む（[antigravity.google/docs/rules](https://antigravity.google/docs/rules)）。ただし同じページでも、App、CLI、IDE ごとの一覧は `~/.gemini/AGENTS.md`、`~/.gemini/GEMINI.md`、`~/.gemini/config/rules/*.md`（CLI はこれに `~/.gemini/antigravity-cli/rules/*.md`）だけを挙げ、`~/.gemini/config/AGENTS.md` を載せていない。Gemini CLI からの移行ページは、`agy` のグローバルファイルとして `~/.gemini/GEMINI.md` だけを挙げる（[cli/gcli-migration](https://antigravity.google/docs/cli/gcli-migration)）。rules ページのどの一覧にも載っているのは `~/.gemini/AGENTS.md` と `~/.gemini/GEMINI.md` である。
- プロジェクト: 任意のディレクトリの `AGENTS.md` か `GEMINI.md`、`.agents/AGENTS.md`、`.agents/rules/*.md` を読む。ファイルを読み書きするたびに、そのフォルダからワークスペースルートまで遡る（[rules](https://antigravity.google/docs/rules)）。
- 優先順位: 「Rules are cumulative rather than replacement-based ... When instructions conflict, more specific directory rules take priority.」AGENTS.md と GEMINI.md は frontmatter を持たず、常時有効（`always_on`）として扱われる（[rules](https://antigravity.google/docs/rules)）。同じディレクトリに AGENTS.md と GEMINI.md が両方あるときの扱いは未確認（文書は「AGENTS.md or GEMINI.md」とだけ書く）。
- `~/.gemini/AGENTS.md` は、Gemini CLI で `context.fileName` に `AGENTS.md` を入れたときのグローバルパスと同じである（上記 Gemini CLI の節）。

### OpenCode

- グローバル: 「You can also have global rules in a `~/.config/opencode/AGENTS.md` file.」（[opencode.ai/docs/rules](https://opencode.ai/docs/rules/)）
- Claude Code 互換: プロジェクトに AGENTS.md が無ければ `CLAUDE.md`、`~/.config/opencode/AGENTS.md` が無ければ `~/.claude/CLAUDE.md` を読む。`OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` などで無効にできる（[rules](https://opencode.ai/docs/rules/)）。
- 優先順位: 「The first matching file wins in each category.」カテゴリは、作業ディレクトリから上へたどるローカルのファイル、グローバルのファイル、Claude Code のファイルの 3 つ（[rules](https://opencode.ai/docs/rules/)）。リリース v1.19.4 のソースでも、グローバルは `~/.config/opencode/AGENTS.md`、`~/.claude/CLAUDE.md` の順で最初に存在するものを 1 つ採り、プロジェクトは `AGENTS.md`、`CLAUDE.md`、`CONTEXT.md`（非推奨）の順で最初に見つかった名前の一致を全部採る（[session/instruction.ts](https://github.com/anomalyco/opencode/blob/v1.19.4/packages/opencode/src/session/instruction.ts)）。
- `opencode.json`（グローバルは `~/.config/opencode/opencode.json`）の `instructions` に、パス、glob、URL を並べて追加の指示ファイルを読ませられる。「All instruction files are combined with your `AGENTS.md` files.」（[rules](https://opencode.ai/docs/rules/)、[config](https://opencode.ai/docs/config/)）

### Cursor

- プロジェクト: 「Cursor supports AGENTS.md in the project root and subdirectories.」入れ子の AGENTS.md は親と結合され、より具体的なものが優先される（[cursor.com/docs/rules](https://cursor.com/docs/rules)）。Cursor CLI はプロジェクトルートの `AGENTS.md` と `CLAUDE.md` を `.cursor/rules` と一緒に読む（[cursor.com/docs/cli/using](https://cursor.com/docs/cli/using)）。CLAUDE.md は AGENTS.md と同じように読み、常に適用される（[cursor.com/help/customization/rules](https://cursor.com/help/customization/rules)）。
- グローバルな AGENTS.md: 文書化されていない。[docs/rules](https://cursor.com/docs/rules)、[help/customization/rules](https://cursor.com/help/customization/rules)、[docs/cli/using](https://cursor.com/docs/cli/using)、CLI の設定リファレンスを確認した。ユーザー単位の仕組みは、設定画面の User Rules（アカウントに保存）と、端末ローカルの「User rule files in `~/.cursor/rules`」である（[help/customization/rules](https://cursor.com/help/customization/rules)）。`~/.cursor/rules` に置くファイルの形式（`.mdc` と frontmatter が必要か）は未確認。`~/.claude/CLAUDE.md` を読むかどうかも未確認（上記ページに記述なし）。
- 優先順位: 「Team Rules → Project Rules → User Rules. All applicable rules are merged; earlier sources take precedence when guidance conflicts.」（[docs/rules](https://cursor.com/docs/rules)）

### GitHub Copilot

- Copilot coding agent（GitHub 上）: 「You can create one or more `AGENTS.md` files, stored anywhere within the repository. When Copilot is working, the nearest `AGENTS.md` file in the directory tree will take precedence.」ルートの `CLAUDE.md` か `GEMINI.md` も使える（[add-repository-instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)）。
- Copilot CLI: リポジトリルート、作業ディレクトリ、その間のディレクトリ、作業中のファイルまでのあいだにあるディレクトリで `AGENTS.md`、`CLAUDE.md`、`GEMINI.md` などを読む。ユーザー単位は `$HOME/.copilot/copilot-instructions.md` と `$HOME/.copilot/instructions/**/*.instructions.md`。グローバルな AGENTS.md の固定パスはなく、「Directories listed in `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` | Additional `AGENTS.md` and `*.instructions.md` files.」が唯一の指定手段である。複数のファイルは結合され、一般的な優先順位は定められていない（[add-custom-instructions（CLI）](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)）。
- VS Code: `chat.useAgentsMdFile`（既定で有効）でワークスペースルートの AGENTS.md を添付する。入れ子の AGENTS.md は `chat.useNestedAgentsMdFiles`（既定で無効）も有効にしたときだけ読む。個人の常時有効な指示は `~/.copilot/copilot-instructions.md` に置く。Local harness では `chat.useClaudeMdFile` を有効にすると、「User home ~/.claude/CLAUDE.md for personal instructions across all projects」も読む。指示は加算的で、文書は順序に頼らないよう勧めている（[code.visualstudio.com/docs/agent-customization/custom-instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)）。VS Code でユーザー単位の AGENTS.md は文書化されていない（同ページを確認）。

### pi coding agent

- リポジトリ `badlogic/pi-mono` は `earendil-works/pi` に移っている（GitHub API の `full_name`）。
- グローバル: 「`<agent-dir>/AGENTS.override.md`, `AGENTS.md`, `AGENTS.MD`, `CLAUDE.md`, or `CLAUDE.MD` | User instructions applied across working directories.」agent dir の既定は `~/.pi/agent`（[configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)）。
- プロジェクト: 作業ディレクトリとその上位から読む。作業ディレクトリより下は読まない。1 ディレクトリにつき上記の候補のうち最初に存在する 1 ファイルを採り、グローバル、外側の祖先、作業ディレクトリの順に連結する（[configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)、[resource-loader.ts](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/src/core/resource-loader.ts)）。`--no-context-files` で無効にできる（[cli.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/cli.md)）。

## 3. 取り込み（import）構文

| エージェント | 構文 | 指示ファイルへ内容を展開するか | `~/` で始まるパス | 出典 |
| - | - | - | - | - |
| Claude Code | `@path` | する。最大 4 段まで再帰 | 使える（文書に `@~/.claude/my-project-instructions.md` の例がある） | [memory#import-additional-files](https://code.claude.com/docs/en/memory#import-additional-files) |
| Gemini CLI | `@./file.md`、`@/abs/path.md` | する。最大 5 段 | 認識されない（下記） | [memport.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/memport.md) |
| Antigravity | `@[label](path)` | する | 展開される | [rules](https://antigravity.google/docs/rules) |
| Antigravity | `@filename` | しない（パスを絶対パスに書き換えるだけ） | - | [rules](https://antigravity.google/docs/rules) |
| Copilot CLI | `@` + 相対パス | する。参照先の参照もたどる | 読まない（下記の食い違いに注意） | [add-custom-instructions（CLI）](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions) |
| Codex CLI | なし | - | - | [ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)、[mod.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/codex-home/src/instructions/mod.rs) |
| OpenCode | なし（`instructions` 設定で代替） | - | `instructions` では使える | [rules](https://opencode.ai/docs/rules/)、[instruction.ts](https://github.com/anomalyco/opencode/blob/v1.19.4/packages/opencode/src/session/instruction.ts) |
| Cursor | `@file` は参照だけ | しない | - | [docs/rules](https://cursor.com/docs/rules) |
| VS Code（Copilot） | Markdown のリンク | しない | - | [custom-instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions) |
| pi | なし | - | - | [configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)、[resource-loader.ts](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/src/core/resource-loader.ts) |

補足:

- Claude Code: 相対パスは import を書いたファイルからの相対で解決する。コードスパンとフェンス付きコードブロックの中の `@` は展開しない。`~/.claude/CLAUDE.md` のようなユーザー単位のファイルの import は確認ダイアログなしで読み込まれる（Cowork のセッションを除く）。Claude Code が AGENTS.md を直接読む場合も、AGENTS.md 内の `@path` は展開される（[memory#import-additional-files](https://code.claude.com/docs/en/memory#import-additional-files)、[memory#when-claude-code-reads-agentsmd](https://code.claude.com/docs/en/memory#when-claude-code-reads-agentsmd)）。import は長いファイルを整理する手段で、文脈の消費は減らない（[memory#write-effective-instructions](https://code.claude.com/docs/en/memory#write-effective-instructions)）。
- Gemini CLI: 以下はソースから読み取った挙動で、文書には書かれていない。`@` の直後の文字が `.`、`/`、英字のどれかでないと import として認識しないので、`@~/...` はそのまま文字列として残る（[memoryImportProcessor.ts の findImports](https://github.com/google-gemini/gemini-cli/blob/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005/packages/core/src/utils/memoryImportProcessor.ts)）。また import 先は、import 元ファイルのディレクトリから上へ境界マーカー（既定は `.git`。`context.memoryBoundaryMarkers` で変更可）を探して決めた「プロジェクトルート」の中に限られる。マーカーが見つからなければ import 元ファイルのディレクトリ自体がルートになる。ルートの外へ出る import は `<!-- Import failed: ... - Path traversal attempt -->` に置き換わる。シンボリックリンクは実体パスに解決してから判定する（同ファイルの `processImports`、`findProjectRoot`、`validateImportPath`）。したがって、ホームが git リポジトリでない環境では、`~/.gemini/GEMINI.md` から `~/.gemini` の外にあるファイル（例: `~/.claude/skills/...`）を import できないと考えられる。実機では試していないので、この結論は未確認として扱う。文書は「imports are only allowed from specified directories」とだけ書く（[memport.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/memport.md)）。
- Copilot CLI: How-to ページは「Referenced files must remain within the repository, or within the custom instructions directory for local instructions. Absolute paths and paths beginning with `~/` are not loaded」「File references are not expanded in `GEMINI.md` or `*.instructions.md` files」と書く（[add-custom-instructions（CLI）](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)）。一方、CLI リファレンスは「Paths can be relative to the instruction file's directory or absolute」と書く（[cli-command-reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)）。絶対パスを読むかどうかは二つの公式ページで食い違っており、未確認。
- 構文をサポートしないエージェントでは、`@~/.claude/skills/x/SKILL.md` の行はただの文字列としてモデルに渡る。その先を読むかどうかはモデルの判断になる。Cursor は「Agent reads the file when it needs it; the contents aren't inlined, so put anything that must always be in context in the rule body.」と明記している（[help/customization/rules](https://cursor.com/help/customization/rules)）。OpenCode は「opencode doesn't automatically parse file references in `AGENTS.md`」と書き、参照を見たら Read ツールで読むよう AGENTS.md に指示を書く方法を示している（[rules](https://opencode.ai/docs/rules/)）。どちらの文書も、参照先が毎回確実に読まれるとは保証していない。

## 4. サイズの上限と切り詰め

| エージェント | 上限 | 超えたとき | 出典 |
| - | - | - | - |
| Claude Code（起動時に読む CLAUDE.md） | 1 ファイル 4 MiB | 読み込まない | [memory](https://code.claude.com/docs/en/memory)（auto memory の節の注記） |
| Claude Code（サブディレクトリの CLAUDE.md と import 先、パス指定の rules） | 200K 文脈で 40,000 文字、1M 文脈で 150,000 文字（Opus 4.6 と Sonnet 4.6 は 200,000 文字） | 先頭だけ渡し、残りは Read ツールで読むよう促す注記を付ける | [memory#claude-ignores-the-end-of-my-subdirectory-claudemd](https://code.claude.com/docs/en/memory#claude-ignores-the-end-of-my-subdirectory-claudemd) |
| Claude Code（推奨） | 1 ファイル 200 行未満 | - | [memory#write-effective-instructions](https://code.claude.com/docs/en/memory#write-effective-instructions) |
| Claude Code（フックの `additionalContext` など） | 10,000 文字。設定で上げられない | ファイルに保存し、パスと先頭 2,000 文字のプレビューに置き換える。Claude にそのファイルを読むよう促さない | [hooks](https://code.claude.com/docs/en/hooks)（JSON output の節） |
| Codex CLI（プロジェクトの AGENTS.md） | `project_doc_max_bytes` 既定 32 KiB（32768） | 合計が上限に達したところで追加を止め、超えたファイルは切り詰める | [ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)、[defaults.toml](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/config/defaults.toml)、[agents_md.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/core/src/agents_md.rs) |
| Gemini CLI | バイト数の上限は見つからない。下位ディレクトリの探索は 200 ディレクトリ、import は 5 段 | - | [configuration.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md)、[memport.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/memport.md) |
| Antigravity | 1 ファイル 24,000 バイト（`@[label](path)` 展開後）、常時有効な rules 全体で 20,000 トークン | 1 ファイルの超過分は切り詰める。全体の超過は大きいファイルから本文を外してポインタに置き換える | [rules](https://antigravity.google/docs/rules) |
| Cursor | 推奨は 500 行未満。強制的な上限は見つからない | - | [docs/rules](https://cursor.com/docs/rules) |
| OpenCode | 見つからない（[rules](https://opencode.ai/docs/rules/)、[config](https://opencode.ai/docs/config/)、[instruction.ts](https://github.com/anomalyco/opencode/blob/v1.19.4/packages/opencode/src/session/instruction.ts) を確認）。リモートの指示は 5 秒でタイムアウト | - | 同左 |
| Copilot | 数値の上限は見つからない。CLI の import に「depth limit, with cycle and size guards」とあるだけ | - | [cli-command-reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference) |
| pi | 見つからない（[configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)、[resource-loader.ts](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/src/core/resource-loader.ts) を確認） | - | 同左 |

補足:

- Codex の `project_doc_max_bytes` はプロジェクトの AGENTS.md の合計に掛かる。ソースでは、グローバルの `~/.codex/AGENTS.md` はこの予算の外で読まれ、切り詰められない。`load_project_instructions` は予算 `remaining` を `project_doc_max_bytes` から始め、プロジェクトのファイルを読むたびに減らすが、グローバルの指示はこの関数に渡される前に読まれていて予算を減らさない（[agents_md.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/core/src/agents_md.rs)、[mod.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/codex-home/src/instructions/mod.rs)）。文書はこの区別を書いていない。
- Antigravity の 24,000 バイトはバイト数である。日本語は UTF-8 で 1 文字 3 バイトになるので、文字数では 8,000 字前後で上限に届く。このリポジトリの `skills/japanese-tech-writing/SKILL.md` は、frontmatter を除いて 9,339 文字、26,733 バイトある（2026-10-26 に `wc -m` と `wc -c` で計測）。
- Agent Skills の仕様は SKILL.md 本文を 5,000 トークン未満、500 行未満にするよう推奨する（[agentskills.io/specification](https://agentskills.io/specification)）。

## 5. 一つの指示ファイルを複数のエージェントで共有する方法

各ツールの文書が勧める方法を挙げる。

- agents.md: 既存のファイルを AGENTS.md に改名し、旧名からシンボリックリンクを張る（[FAQSection.tsx](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。
- Claude Code: AGENTS.md の隣に `@AGENTS.md` だけを書いた CLAUDE.md を置き、Claude 固有の指示をその下に書く。Claude 固有の指示が無ければ `ln -s AGENTS.md CLAUDE.md` でもよい。ただし Edit と Write ツールはシンボリックリンク越しに書き込まない。Windows で clone する人がいるなら import を使うよう案内されている（[memory#share-one-file-with-other-coding-tools](https://code.claude.com/docs/en/memory#share-one-file-with-other-coding-tools)）。以前の回避策（`@AGENTS.md` を書いた CLAUDE.md、シンボリックリンク）は残しても二重には読まれない。AGENTS.md を出力する SessionStart フックは二重読み込みになるため削除するよう案内されている（[memory#remove-an-earlier-agentsmd-workaround](https://code.claude.com/docs/en/memory#remove-an-earlier-agentsmd-workaround)）。これらはプロジェクト単位の説明である。ユーザー単位で `~/.claude/CLAUDE.md` から AGENTS.md を共有する手順は文書にない。ただし import の説明に `@~/...` の例があり、ユーザー単位のファイルの import はダイアログなしで読み込まれるので、`~/.claude/CLAUDE.md` に `@~/.codex/AGENTS.md` のような行を書く方法は文書の範囲で成り立つ（[memory#import-additional-files](https://code.claude.com/docs/en/memory#import-additional-files)）。`~/.claude/CLAUDE.md` 自体をシンボリックリンクにする方法は、Cowork のセッションではシンボリックリンクの `~/.claude/CLAUDE.md` を読まない、という記述があるだけで、通常のセッションで読むと明記した箇所はない。この方法が通常のセッションで動くかは未確認。
- Gemini CLI: `context.fileName` に `AGENTS.md` を入れる（[gemini-md.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md)、[agents.md の FAQ](https://github.com/agentsmd/agents.md/blob/d001185d792eb6402a58e4cbef1c228b309ec25d/components/FAQSection.tsx)）。
- OpenCode: `opencode.json` の `instructions` で既存のファイルを読ませる。「This allows you and your team to reuse existing rules rather than having to duplicate them to AGENTS.md.」また参照ファイルを「Share rules across projects via symlinks or git submodules」とも書く（[rules](https://opencode.ai/docs/rules/)）。`instructions` は `~/` で始まるパスと絶対パスを受け付ける（[instruction.ts](https://github.com/anomalyco/opencode/blob/v1.19.4/packages/opencode/src/session/instruction.ts) の `raw.startsWith("~/")` の処理）。`~/.claude/CLAUDE.md` を自動で読むので、Claude Code 用のグローバルファイルがそのまま OpenCode にも渡る点に注意する（[rules](https://opencode.ai/docs/rules/)）。
- Codex CLI: プロジェクトでは `project_doc_fallback_filenames` で別名のファイルを指示ファイルとして扱える（[ガイド](https://learn.chatgpt.com/docs/agent-configuration/agents-md)）。グローバルでは使えない（第 2 節）。シンボリックリンクについて文書は何も書かない。ソースは `tokio::fs::metadata` と `tokio::fs::read` を使い、どちらもリンクをたどるので、`~/.codex/AGENTS.md` をシンボリックリンクにしても読めるはずである（[mod.rs](https://github.com/openai/codex/blob/970111f6cb62cc02fe36a82ea7d71b37a2889c97/codex-rs/codex-home/src/instructions/mod.rs)）。実機では試していないので未確認。
- GitHub Copilot: VS Code の文書は「If your team uses multiple harnesses, use a shared format that they all support when possible」と書き、複数のエージェントで一つの指示を共有したいなら AGENTS.md を使うよう勧めている（[custom-instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)）。Copilot CLI は CLAUDE.md、GEMINI.md、`.claude/rules` もそのまま読む（[add-custom-instructions（CLI）](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)）。ユーザー単位の AGENTS.md は `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` で渡す（同ページ）。
- Cursor: CLAUDE.md を AGENTS.md と同じく読む（[help/customization/rules](https://cursor.com/help/customization/rules)）。シンボリックリンクについての記述は見つからない（[docs/rules](https://cursor.com/docs/rules)、[help/customization/rules](https://cursor.com/help/customization/rules)、[docs/skills](https://cursor.com/docs/skills) を確認）。
- Antigravity: AGENTS.md と `.agents/` を読むことが他のエージェントとの互換性を保つ手段になっている。プロジェクト間の共有には `.agents/rules.json` の `inherits` と `entries` を使う（[rules](https://antigravity.google/docs/rules)）。シンボリックリンクについての記述は見つからない（rules、skills、cli/best-practices ほかを確認）。
- pi: グローバルとプロジェクトの両方で CLAUDE.md を AGENTS.md の代わりに読む（[configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)）。シンボリックリンクの推奨は文書にない。

## 6. スキル（SKILL.md、Agent Skills）との関係

### 読み込みの仕組み

Agent Skills の仕様では、起動時に全スキルの `name` と `description`（約 100 トークン）だけを読み込み、スキルが有効化されたときに SKILL.md の本文を読む（[agentskills.io/specification](https://agentskills.io/specification) の Progressive disclosure）。仕様はスキルの置き場所を定めない。クライアント実装者向けの文書は、ユーザー単位で `~/.<クライアント名>/skills/` と相互運用用の `~/.agents/skills/` を走査するよう勧め、「project-level skills override user-level skills」を慣習として挙げる（[adding-skills-support](https://agentskills.io/client-implementation/adding-skills-support)）。

各エージェントの説明も同じで、スキルは description との一致で必要なときに読み込まれる。Claude Code は「Description always in context, full skill loads when invoked」（[skills](https://code.claude.com/docs/en/skills)）、Codex は「Implicit invocation: ChatGPT or Codex can choose a skill when your task matches the skill `description`.」（[build-skills](https://learn.chatgpt.com/docs/build-skills)）、Gemini CLI は「Skills represent on-demand expertise」（[skills.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md)）と書く。

### スキルを常時有効にする方法

| エージェント | 文書化された方法 | 出典 |
| - | - | - |
| Claude Code | 通常のセッションにはない。サブエージェントの `skills` フィールドで指定したスキルは、そのサブエージェントの起動時に本文ごと注入される。一度呼ばれたスキルの本文は以後の会話に残る（圧縮後は先頭 5,000 トークンまで再添付） | [skills](https://code.claude.com/docs/en/skills)（Control who invokes a skill、Skill content lifecycle） |
| Codex CLI | ない。`allow_implicit_invocation: false` で暗黙の呼び出しを止める設定だけがある | [build-skills](https://learn.chatgpt.com/docs/build-skills) |
| Gemini CLI | 見つからない（[skills.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md) を確認） | - |
| Cursor | frontmatter での指定はない。スキルを Custom Mode として使うとセッション中は文脈に残る | [docs/skills](https://cursor.com/docs/skills) |
| Copilot | 見つからない。VS Code の比較表はスキルを「loaded on-demand」、指示ファイルを「Always applied」とする | [agent-skills（GitHub）](https://docs.github.com/en/copilot/concepts/customizations/agent-skills)、[agent-skills（VS Code）](https://code.visualstudio.com/docs/agent-customization/agent-skills) |
| Antigravity | 見つからない。常時有効にする仕組みは rules（`always_on`、AGENTS.md、GEMINI.md）である | [skills](https://antigravity.google/docs/skills)、[rules](https://antigravity.google/docs/rules) |
| OpenCode | 見つからない（[skills](https://opencode.ai/docs/skills/) を確認） | - |
| pi | ない。呼び出しごとに `/skill:name` で強制できるだけ | [skills.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md) |

Agent Skills の仕様にも常時有効の指定はない（[specification](https://agentskills.io/specification)）。スキルの定義（frontmatter や設定）で、全てのセッションに常時読み込ませる方法を文書化したエージェントはない。近いものは、Cursor の Custom Mode（一つのセッションの間だけ有効）と、Claude Code のサブエージェントへの事前読み込み（そのサブエージェントの中だけ）である。毎セッションのメインの文脈に置きたい内容は、どのエージェントでも指示ファイル（AGENTS.md など）に書くのが文書化された方法である。

### ユーザー単位のスキルディレクトリ

| エージェント | ユーザー単位 | `~/.agents/skills` | `~/.claude/skills` | 出典 |
| - | - | - | - | - |
| Claude Code | `~/.claude/skills/` | 文書化されていない | 読む | [skills#choose-where-skills-load](https://code.claude.com/docs/en/skills) |
| Codex CLI | `$HOME/.agents/skills`（ほかに `/etc/codex/skills`） | 読む | 文書化されていない | [build-skills](https://learn.chatgpt.com/docs/build-skills) |
| Gemini CLI | `~/.gemini/skills/` | 読む（同じ階層では `.agents` が優先） | 文書化されていない | [skills.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md) |
| Antigravity CLI（`agy`） | `~/.gemini/antigravity-cli/skills/` | 文書化されていない | 文書化されていない | [skills](https://antigravity.google/docs/skills)、[cli/gcli-migration](https://antigravity.google/docs/cli/gcli-migration) |
| Antigravity App / IDE | `~/.gemini/config/skills/`（IDE は旧 `~/.gemini/antigravity/skills/` も） | 文書化されていない | 文書化されていない | [skills](https://antigravity.google/docs/skills) |
| OpenCode | `~/.config/opencode/skills/` | 読む | 読む | [skills](https://opencode.ai/docs/skills/) |
| Cursor | `~/.cursor/skills/` | 読む | 読む（`~/.codex/skills/` も） | [docs/skills](https://cursor.com/docs/skills) |
| Copilot CLI | `~/.copilot/skills/` | 読む | 文書化されていない | [cli-plugin-reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference)（読み込み順の図。`~/.copilot/skills/`、`~/.agents/skills/` の順で、同名は先に読んだものを使う）。Copilot 全般の [agent-skills](https://docs.github.com/en/copilot/concepts/customizations/agent-skills) は「Supported locations depend on the surface」と書く |
| VS Code（Copilot） | `~/.copilot/skills/` | 読む | 読む | [agent-skills（VS Code）](https://code.visualstudio.com/docs/agent-customization/agent-skills) |
| pi | `~/.pi/agent/skills/` | 読む | 文書化されていない | [configuration.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)（`<agent-dir>/skills/`）、[skills.md](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md) |

Codex の文書は `~/.codex/skills` について何も書いていない（[build-skills](https://learn.chatgpt.com/docs/build-skills)）。Codex と Claude Code は、スキルのフォルダをシンボリックリンクにできると明記している（[build-skills](https://learn.chatgpt.com/docs/build-skills)、[skills](https://code.claude.com/docs/en/skills)）。他のエージェントがスキルのフォルダのシンボリックリンクをたどるかは未確認。

## 例の書き換えへの含意

- グローバルな AGENTS.md を一か所に置けば全エージェントが読む、という場所は存在しない。agents.md の規約はグローバルファイルを定めず、パスはエージェントごとに違う。実体を一つ置き、各パスへシンボリックリンクを張るか、各エージェントの設定でその実体を指す必要がある。各パスは次のとおり。
  - Codex: `~/.codex/AGENTS.md`
  - OpenCode: `~/.config/opencode/AGENTS.md`（無ければ `~/.claude/CLAUDE.md` を読む）
  - Antigravity（`agy` を含む）: `~/.gemini/AGENTS.md`
  - Gemini CLI: `~/.gemini/AGENTS.md`（`~/.gemini/settings.json` の `context.fileName` に `AGENTS.md` を入れた場合）。Antigravity と同じファイルになる。
  - pi: `~/.pi/agent/AGENTS.md`
  - Copilot CLI: `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` に実体のあるディレクトリを入れる。固定パスのユーザー単位ファイルは `~/.copilot/copilot-instructions.md` と `~/.copilot/instructions/**/*.instructions.md` で、AGENTS.md の名前では読まない。
  - VS Code（Copilot）: `~/.copilot/copilot-instructions.md`。Local harness で `chat.useClaudeMdFile` を有効にすれば `~/.claude/CLAUDE.md` も読む。
  - Claude Code: ユーザー単位の AGENTS.md は読まない。`~/.claude/CLAUDE.md` に `@<実体のパス>` を書く。
  - Cursor: ファイルで渡すグローバルな AGENTS.md はない。設定画面の User Rules か `~/.cursor/rules` を使う（後者のファイル形式は未確認）。
- 例のタイトルと説明から「Claude Code の `~/.claude/CLAUDE.md`」を外し、上の置き場所の表（または該当するエージェントに絞った表）を「前提」に置く。シンボリックリンクについては、Codex はソースコード上ではリンクをたどり、OpenCode は文書で参照ファイルの共有に勧めているが、グローバルファイル自体をリンクにした場合の動作を明記した公式文書はどのエージェントにもない。この点は例の中で「確かめ方」として扱う。
- `@~/.claude/skills/japanese-tech-writing/SKILL.md` の import 行が本文を展開するのは Claude Code だけである。
  - Gemini CLI は `@~` を import と認識しない。ソースから読む限り、ホームが git リポジトリでなければ `~/.gemini` の外のファイルは import できない（実機では未確認）。
  - Antigravity は `@[label](~/...)` という別の構文なら展開するが、`@~/...` は展開しない。
  - Copilot CLI は `~/` で始まる参照を読まない。
  - Codex、OpenCode、Cursor、pi、VS Code では、この行はただの文字列である。
  - したがって共有する AGENTS.md に `@` 行を書いても、Claude Code 以外では規範は毎セッション読み込まれない。
- import に頼らない書き方は二つある。
  - 規範の本文（または要点）を AGENTS.md に直接書く。
  - スキルのパスを示して読むよう指示する文を書く。ただしこれは Cursor と OpenCode の文書が示すとおりモデル任せで、常時読み込みにはならない。例でこの方法を採るなら、常時有効にはならないことを明記する。
- 本文を直接書く場合はサイズに注意する。`japanese-tech-writing/SKILL.md` の本文は 26,733 バイトで、Antigravity の 1 ファイル 24,000 バイトの上限を超え、切り詰められる。Codex のグローバルファイルはソース上は `project_doc_max_bytes`（32 KiB）の外だが、プロジェクトの AGENTS.md は 32 KiB を共有する。Claude Code は 200 行未満を推奨している。全文を転記するより、優先順位の一文と、チャットの返答で守らせたい要点だけを書くほうが、どのエージェントでも上限に収まる。
- Claude Code だけは `~/.claude/CLAUDE.md` に `@` 行を残せば全文を常時読み込める。例を「共通の AGENTS.md（要点）」と「Claude Code 用の `~/.claude/CLAUDE.md`（`@<AGENTS.md の実体>` と `@~/.claude/skills/japanese-tech-writing/SKILL.md`）」の二段に分ける構成が、文書化された挙動と矛盾しない。OpenCode は `~/.config/opencode/AGENTS.md` があれば `~/.claude/CLAUDE.md` を読まないので、二段構成でも二重読み込みにはならない。
- スキルの定義で全セッションに常時読み込ませる方法は、どのエージェントにも文書化されていない（Cursor の Custom Mode は一つのセッションだけ、Claude Code の事前読み込みはサブエージェントの中だけ）。「スキルとして入れただけでは、必要と判断されたときしか読み込まれない」という現行の例の説明は、他のエージェントにもそのまま当てはまる（第 6 節）。
- japanese-tech-writing をスキルとしても入れておくなら、`~/.agents/skills/` に置くと Codex、Gemini CLI、OpenCode、Cursor、Copilot、pi が読む。Claude Code と Antigravity はこのディレクトリを文書化していないので、`~/.claude/skills/` と `~/.gemini/antigravity-cli/skills/`（`agy`）へのリンクか複製が別に要る。
- 現行の例は、i-have-adhd が Claude Code のプラグインの SessionStart フックで注入されることを前提にしている。他のエージェントで i-have-adhd の規則をどう読み込ませるかは、この調査の範囲外で未確認である。共有する AGENTS.md に優先順位の一文を書く場合、i-have-adhd が読み込まれていないエージェントでは、その一文の前半は意味を持たない。
- SessionStart フックの 10,000 文字の上限は Claude Code の文書で確認できた（第 4 節）。現行の例の説明はこの点で正しいが、フックは Claude Code 固有の仕組みなので、共有版の例では Claude Code 用の補足に移す。
