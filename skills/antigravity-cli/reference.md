# Antigravity CLI リファレンス

表記の意味:
- **[公式]** Google の公式ドキュメント（antigravity.google/docs）の記述
- **[検証済み]** この環境（v1.3.4、macOS arm64）で実行して確認した内容（2026-10-13）
- **[changelog]** `agy changelog` に載っている 1.3.4 までの変更点
- **[第三者]** ブログ、ガイド、GitHub issue など。実機では未確認
- **[要確認]** 公式ページどうし、または公式と実機で食い違っている内容

## 導入

- **[公式]** macOS / Linux: `curl -fsSL https://antigravity.google/cli/install.sh | bash`
- **[公式]** Windows PowerShell: `irm https://antigravity.google/cli/install.ps1 | iex`
- **[検証済み]** バイナリは `~/.local/bin/agy`（Mach-O arm64、約 173 MB）
- **[検証済み]** `agy install` が `~/.zshrc` と `~/.zprofile` に、`# Added by Antigravity CLI installer` のコメント付きで `export PATH="$HOME/.local/bin:$PATH"` を追記した。`~/.zshrc` には別行の `export PATH="$HOME/.local/bin:$PATH"` もあり、PATH が重複している。こちらはコメントが無いため、導入前からあった可能性もある。動作に支障はない
- **[検証済み]** 導入された版は `1.3.4` と見られる（`agy changelog` の先頭）。`agy --help` に `--version` は無い
- **[公式]** 初回は `agy` を起動する。ブラウザで Google アカウントの認証を行い、表示テーマと表示モードを選び、ワークスペースの信頼を確認する
- **[公式]** アンインストールの手順は見つからなかった
- 導入スクリプトの確認（実行はしていない。取得ツールの要約で読んだので、原文は未確認）:
  - マニフェストは Cloud Run のホスト（`antigravity-cli-auto-updater-974169037036.us-central1.run.app`）から取得する。バイナリの URL はマニフェストの `url` で指定され、そのホストは未確認。SHA512 はマニフェストと照合するため、改ざん検知は限定的
  - `~/.local/bin/agy` に配置し、macOS では `com.apple.quarantine` 属性を外す
  - 最後に `agy install` を実行し、失敗は無視される（`|| true`）。PATH の追記以外の変更は未確認
  - CLI はバックグラウンドで自己更新する（スクリプトの通知文より）

## CLI の構成

- **[検証済み]** サブコマンド（`agy --help`）: `agent` / `agents`、`changelog`、`help`、`install`、`mcp`、`mic-serve`、`models`、`plugin` / `plugins`、`remote-control`、`update`
- **[検証済み]** `agy models` の一覧（2026-10-13 時点）:
  - `gemini-3.8-flash-high`、`gemini-3.8-flash-medium`、`gemini-3.8-flash-low`
  - `claude-sonnet-4-6`（Thinking）
  - `claude-opus-4-6-thinking`
  - `gpt-oss-120b-medium`

## ヘッドレス実行

- **[公式]** `-p "..."`。別名は `--print`、`--prompt`
- **[検証済み]** 主なフラグ（v1.3.4 の `--help` に基づく）:

| フラグ | 内容 |
| --- | --- |
| `--output-format` | `text`（既定）、`json`、`stream-json` |
| `--input-format` | `text`（既定）、`stream-json`（stdin から 1 行 1 メッセージ。`--output-format stream-json` との併用が必要） |
| `--json-schema` | 構造化出力のスキーマ（文字列またはファイルパス） |
| `--model` | モデル名。`agy models` の一覧から選ぶ |
| `--effort` | `low`、`medium`、`high`、`xhigh`、`max` |
| `--agent` | エージェント名。`agy agents` で一覧 |
| `-c`、`--continue` | 直近の会話を再開する |
| `--conversation <id>` | 指定 ID の会話を再開する |
| `--print-timeout` | 応答の最大待ち時間。既定は `0s`（完了まで待つ）。公式ページは `5m` と記すが、この版の help は `0s` |
| `--mode` | `accept-edits` または `plan` |
| `--add-dir` | 作業ディレクトリに追加するディレクトリ（繰り返し可） |
| `--log-file` | CLI のログファイルの場所を変更する |
| `--disable-slash-commands` | print mode でスラッシュコマンドとスキルの展開を無効にする |
| `--sandbox` | ターミナルのサンドボックス制限を有効にする |
| `--dangerously-skip-permissions` | 全ツールを自動承認する。使用は非推奨 |
| `--project`、`--new-project` | プロジェクトの指定と作成（未使用） |

- **[検証済み]** `--cwd` は未定義。使うと `flags provided but not defined: -cwd` と出て exit 2 で終わる。公式ベストプラクティスの例（`--cwd $(pwd)`）はこの版では使えない。`(cd <dir> && agy -p ...)` で代用する
- **[検証済み]** `--mode` の値は `accept-edits` と `plan` のみ。公式モードのページは `default` を挙げているが、指定はできない
- **[公式]** `--mode` は 1 回の実行だけ、保存された既定値を上書きする

### 出力と終了コード

- **[公式]** text の場合、応答は stdout。エラー、認証の案内、進捗、権限の通知は stderr
- **[検証済み]** json の envelope のキー: `conversation_id`、`status`、`response`、`duration_seconds`、`num_turns`、`usage`（`input_tokens`、`output_tokens`、`thinking_tokens`、`cache_read_tokens`、`total_tokens`）、`denied_actions`（拒否された操作の配列。例: `[{"action":"command","display_name":"RunCommand"}]`）。`error` は失敗時に出る（公式）
- **[検証済み]** 拒否が 1 件も無いと、`denied_actions` のキー自体が envelope に出ない（2026-10-14）
- **[検証済み]** `--json-schema <ファイルパス>` を付けると、envelope に `structured_output`（スキーマに沿ったオブジェクト）と `json_schema` が加わる。`response` には説明文が別に入る（2026-10-14）
- **[公式]** `status` の値: `SUCCESS`、`ERROR`、`CANCELED`、`INTERRUPTED`、`INVALID`、`WAITING`、`RUNNING`
- **[検証済み]** 成功時の exit は 0。不明なフラグは exit 2（usage エラー）
- **[公式]** 応答が得られなかった場合は非 0 で、理由は stderr に出る
- **[公式]** 未知の `--model` は exit 1（`ERROR`）。黙って別モデルに切り替えることはない
- **[changelog]** `--agent` の名前が見つからない場合、headless の `-p` は exit 1 で終わり、利用可能なエージェントを一覧表示する
- **[changelog]** `--print` と `--prompt-interactive` を同時に使うと exit 2
- **[公式]** `stream-json` の入力モードでは stdin がプロンプトになり、`-p` のプロンプトは捨てられる
- **[公式]** `/model` や `/usage` などの CLI 内スラッシュコマンドは、ストリーミングセッションでは使えない。`agy -p /model` のように単独で実行する

## 権限

- **[検証済み]** 承認が必要な操作は、headless では拒否される（soft-deny）。`git status` を頼んだ実験の結果: exit 0、`status` は `SUCCESS`、`response` は空、`denied_actions` に `command` が記録され、stderr に次の通知が出た。
  `jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.`
- **[検証済み]** 同じ stderr は、`permissions.allow` に `command(<対象>)` を追加するか、`--dangerously-skip-permissions` で再実行するよう案内している。後者は採用しない
- **[公式]** 作業ディレクトリ内のファイル読み書きは自動許可。シェルコマンドは既定で Ask となり、承認者がいなければ拒否される
- **[検証済み]** 設定ファイル `~/.gemini/antigravity-cli/settings.json` の現状は `{"trustedWorkspaces": ["<ホームディレクトリ>"]}` のみ。`permissions` は未設定（2026-10-13 時点）
- **[公式]** `permissions` の配列: `allow`、`deny`、`ask`

```json
{
  "permissions": {
    "allow": ["command(git)"],
    "deny": ["command(sudo)"],
    "ask": ["command(*)"]
  }
}
```

- **[公式]** ルールの形式: `command(prefix)`、`command(regex:パターン)`、`command(*)`
- **[公式]** 評価順: Deny > Ask > Allow
- **[公式]** パイプや `&&`、`||`、`;` の連結は、先頭のプレフィックスで一致判定される。`git status && git log` は `command(git)` だけで承認なしに通る
- **[公式]** `$(...)`、バッククォート、`<(...)`、ブレース展開などを含むコマンドは完全一致扱いになり、プロンプトが出る
- **[要確認]** 権限の設定キーは公式ページどうしで食い違っている
  - ベストプラクティスのページ: `toolPermission`（`request-review`、`proceed-in-sandbox`、`strict`）と `enableTerminalSandbox`
  - パーミッションのページ: デスクトップ版のプリセット（Default、Request Review、Turbo）と、CLI の allow、deny、ask
  - 実機では未確認。設定を変える前に `/settings` の表示を確認する
- **[公式]** モードの設定: `agentMode`（settings）、`--mode`（1 回だけの上書き）、対話中は `Shift+Tab` で切り替え
- **[公式]** サンドボックス: ターミナルコマンドはワークスペースと一時ディレクトリだけにアクセスでき、既定ではネットワークを使えない。ネットワークが必要なコマンドは、サンドボックス外での実行を求め、それにも承認が要る

## 認証

- **[公式]** 初回は対話で `agy` を起動してブラウザ認証する。以後はキャッシュされた資格情報を使う
- **[公式]** 非対話の実行で未認証なら、ハングせず `authentication required` で終了する
- **[検証済み]** 現在は `agy models` と `-p` の実行がどちらも成功しており、認証済みと見られる
- **[第三者]** API キーを使う方法もある。ただし、キーをプロンプトやコマンド引数に書かないこと

## 既知の問題

- **[第三者]** GitHub issue [google-antigravity/antigravity-cli#318](https://github.com/google-antigravity/antigravity-cli/issues/318): 標準入出力が端末でない場合（サブプロセスやリダイレクト）に `agy -p` が戻らない。報告は v1.0.6 で、`--sandbox` を付けても改善しなかった
- **[検証済み]** v1.3.4 では、`< /dev/null` を付け、stdout と stderr をファイルへリダイレクトした条件で、`-p` の実行 3 回（一部は拒否される実験）がいずれも数秒で戻った。`< /dev/null` を付けない条件での再現は未確認

## スキル

- **[検証済み]** グローバルスキルは `~/.gemini/config/skills/<name>/SKILL.md` に置くと、print mode でも読み込まれる。ディレクトリは直下だけが走査され、入れ子は読まれない（changelog）。`~/.gemini/antigravity-cli/builtin/skills/` には組み込みスキルがある（2026-10-14）
- **[検証済み]** `-p` で「ファイルを直接編集して」と頼むと、置換用の Python スクリプトを書いて `RunCommand` で実行しようとし、拒否されて何も変わらずに終わることがある。拒否された実際のコマンドはログに残らず、会話 DB（`~/.gemini/antigravity-cli/conversations/<conversation_id>.db`）を `strings` で見ると分かる。agy が書いたスクリプトは `~/.gemini/antigravity-cli/brain/<conversation_id>/scratch/` に残る（2026-10-14）

## ログ

- **[検証済み]** `~/.gemini/antigravity-cli/log/` にログがあり、`cli.log` が最新のログ（例: `cli-20261013_191912.log`）を指す

## モード

- **[公式]** `default`（パーミッションのページでは `request-review`）、`accept-edits`、`plan`
- **[検証済み]** `--mode` の値は `accept-edits` と `plan` のみ
- **[公式]** `accept-edits`: ファイルの読み取り、作成、置換を自動承認する。サブエージェントも同じ設定を引き継ぐ
- **[公式]** `plan`: 読み取り専用のツールで調べ、コードを書く前に概要を提示して承認を待つ
- **[公式]** シェルコマンドの扱いは、モードに関係なく権限ルールに従う
- **[要確認]** ヘッドレス実行でのモードごとの挙動（とくに `plan` で `WAITING` になるか）は未検証

## 出典

- 導入: https://www.antigravity.google/docs/getting-started?tab=cli
- ヘッドレス: https://www.antigravity.google/docs/cli/headless/
- ベストプラクティス: https://www.antigravity.google/docs/cli/best-practices
- モード: https://www.antigravity.google/docs/cli/modes
- 権限: https://www.antigravity.google/docs/permissions?tab=cli
- 導入スクリプト（読み取りのみ）: https://antigravity.google/cli/install.sh
- CLI 内蔵の変更履歴: `agy changelog`
