#!/bin/sh
# Stop フック。自動保存モード（nudge.sh が置く .over-<セッション ID>）のセッションで、
# このターンに finish.sh commit が実行されていなければ、応答の終了を一度だけ止めて記録の更新を指示する。
# 終了させるときは、/compact か /clear の実行を促す文をユーザーに表示する。
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
dir="$HOME/.claude/save"
[ -f "$dir/.over-$sid" ] || exit 0
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
stamp="$dir/.stamp-$sid" turn="$dir/.turn-$sid"
if [ "$active" != true ] && { [ ! -f "$stamp" ] || [ "$turn" -nt "$stamp" ]; }; then
  jq -n '{decision:"block", reason:"自動保存モードで、このターンの記録がまだコミットされていない。save スキルの「書き出しの手順」の 1、3〜5 に従い、記録を更新してコミットする（記録がなければ 1〜5）。終えたら、/compact か /clear の実行を勧める一行だけを書いて終える。"}'
  exit 0
fi
pct=$(cat "$HOME/.claude/statusline/ctx/$sid.pct" 2>/dev/null)
if [ -f "$stamp" ] && [ ! "$turn" -nt "$stamp" ]; then
  saved="記録は保存済みなので、"
else
  saved="記録の更新に失敗している。/save を実行してから、"
fi
jq -n --arg m "コンテキストの使用率は${pct:-?}%。${saved}/compact か /clear を実行してください。" '{systemMessage:$m}'
