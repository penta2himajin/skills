---
name: antigravity-cli
description: Run Google's Antigravity CLI (agy) from Claude Code in headless print mode to hand off a coding, review, or investigation task, with permission guardrails and checks on what it changed. Includes a proofreading mode where agy returns text edits as JSON and Claude vets them before applying (agy で校正, agy に推敲させて). Use only when the user explicitly asks to use Antigravity, agy, or the Antigravity CLI (アンチグラビティ, agy に任せて, agy で実装, agy で校正).
---

# Antigravity CLI（agy）をヘッドレスで呼ぶ

Google Antigravity CLI（コマンド `agy`）を、非対話の print mode（`agy -p`）で実行し、作業を委任するためのスキル。
v1.3.4 で 2026-10-13 に動作を確認済み。公式ドキュメントと実機の食い違いは [reference.md](reference.md) に書いてある。

## 0. 呼ぶ前に確認すること

1. `command -v agy` で導入済みか確認する。未導入なら、導入コマンドをユーザーに渡して実行してもらう。**curl | bash やインストーラは私（Claude）が実行しない。**
2. `agy --help` で実機のフラグを確認する。公式ドキュメントにあるフラグでも、この版には無いものがある（例: `--cwd`）。
3. 認証済みか確認する。未認証の非対話実行は `authentication required` で終了する。未認証ならユーザーに、対話で `agy` を起動してブラウザ認証するよう依頼する。

## 1. 基本の呼び出し

```bash
(cd "<対象リポジトリの絶対パス>" && agy -p "<依頼内容>" --output-format json --print-timeout 15m < /dev/null > "<scratchpad>/agy-out.json" 2> "<scratchpad>/agy-err.txt"); echo "exit=$?"
```

- 作業ディレクトリは `cd` で移る。`--cwd` は v1.3.4 では未定義で、使うと exit 2 で失敗する。
- `--print-timeout` は必ず指定する。既定は `0s`（完了まで待つ）なので、ハングしたときに止まらない。
- JSON で見るのは `status`、`response`、`denied_actions`、`conversation_id`、`usage`。
- 成功と判定するのは、exit 0、`status` が `SUCCESS`、`denied_actions` が空、`response` が空でない、の 4 つがそろったとき。拒否された場合も exit 0 と `SUCCESS` で返るので、空の `response` と非空の `denied_actions` を見て判断する。拒否が無いときは `denied_actions` のキー自体が出ないので、`d.get('denied_actions')` で読む。
- `--json-schema <ファイル>` を付けると、スキーマに沿った結果が `structured_output` に入る（`response` には説明文が別に入る）。
- `WAITING` は承認待ちで止まった可能性があるので、成功扱いにしない。
- 終了コード: 0 は応答あり。1 は未知の `--agent` や `--model`。2 は使い方の誤り（不明なフラグなど）。
- stderr は別ファイルに保存して読む。拒否の通知も stderr に出る。
- 一時ファイルはセッションの scratchpad に置く。`/tmp` は使わない。
- Bash ツールの timeout（上限 600000ms）は `--print-timeout` より長めにする。
- `< /dev/null` は標準入力待ちを避けるための私の予防策。公式の推奨ではない。

## 2. 権限を理解してから使う（最重要）

- ヘッドレスには承認画面がない。承認が必要な操作は自動で拒否される（検証済み）。実行は続き、stderr に `auto-denied` の通知が出る。
- 既定では、作業ディレクトリ内のファイル読み書きは自動許可される。シェルコマンドは拒否される（検証済み: `git status` は拒否された）。テストやビルドを agy に実行させたい場合は、許可ルールが要る。
- 許可ルールは `~/.gemini/antigravity-cli/settings.json` の `permissions.allow` に、必要最小限だけ書く（例: `"command(git status)"`）。**settings の変更はユーザーの承認を得てから行う。** 現在は `permissions` 未設定。
- stderr は `--dangerously-skip-permissions` での再実行を案内するが、使わない。どうしても必要なら、使い捨ての git worktree かコピーの中に限り、ユーザーの明示的な許可を得る。
- 評価順は deny > ask > allow。`&&`、`|`、`;` の連結はプレフィックス一致で通ることがあるため、allow は狭く書く。`$(...)` やバッククォートは完全一致扱いになる。
- サンドボックスを有効にすると（`--sandbox` や設定）、ネットワークは既定で遮断される。その場合 `npm install` などは拒否されるので、依存の導入は事前に行う。

## 3. 実行の前後

1. 対象 repo で `git status` を確認する。未コミットの変更があれば、混ざらないようユーザーに確認する。自律的に編集させる場合は git worktree か一時ブランチを推奨する。
2. 依頼文に「変更してよい範囲（ファイル・ディレクトリ）」と「完了条件（テストやビルドのコマンド）」を書く。公式は、agy 自身に「実装 → テスト実行 → 修正」の検証ループを回させることを推奨している。
3. 実行後は私が確認する。`git status`、`git diff --stat`、`git diff`、テストやビルドの実行、stderr の拒否通知。agy の「完了しました」は鵜呑みにしない。
4. commit、push、PR 作成は、ユーザーが明示的に指示した場合だけ行う。
5. リポジトリ直下の `AGENTS.md` や `GEMINI.md` は agy が起動時に読む。実行前に中身を確認し、勝手に作成や書き換えをしない。

## 4. モードの使い分け

- 文章の校正・推敲: [proofread.md](proofread.md) の手順に従う。agy には修正案を JSON で返させるだけにして、ファイルは編集させない。Claude が案を一件ずつ判定してから、`scripts/apply_edits.py` で原文のコピーに適用する。

- 調査や計画だけ: `--mode=plan`。読み取り中心で、計画を提示する。ヘッドレスでの挙動（承認待ちで `WAITING` になるか）は未検証。
- 実装: `--mode=accept-edits`。ファイル編集を自動承認する。シェルコマンドは権限ルールに従う。
- `--mode` の値は `accept-edits` と `plan` のみ（`agy --help`）。`default` は指定できない。既定に任せるなら指定しない。

## 5. よくある失敗

| 症状 | 対応 |
| --- | --- |
| `authentication required` | ユーザーに対話で `agy` を起動し、再認証を依頼する |
| `flags provided but not defined`（exit 2） | フラグ名が違うか、この版に無い。`agy --help` で確認する |
| exit 0 だが `response` が空、`denied_actions` が非空 | 権限で拒否されている。権限ルールの追加はユーザーの承認を得てから |
| 出力が返らずハングする | 第三者報告の問題（issue #318、v1.0.6）。v1.3.4 では `< /dev/null` とファイルへのリダイレクトを付けた 3 回の実行がいずれも数秒で戻った。付けない条件での再現は未確認。`--print-timeout` は必ず指定する |
| Bash 側でネットワークや接続のエラーが出る | Bash のサンドボックスが原因の可能性がある。`dangerouslyDisableSandbox` は勝手に使わず、ユーザーに確認する |
| `ERROR` や非 0 の終了 | stderr を読む。ログは `~/.gemini/antigravity-cli/log/` にあり、`cli.log` が最新を指す |

## 6. 報告

- agy の出力はそのまま貼らず要約する。変更したファイル、テスト結果、拒否された操作を明記する。
- 公式で確認した事項、実機で確認した事項、第三者情報だけの事項（[reference.md](reference.md)）を区別して伝える。
