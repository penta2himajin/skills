#!/bin/sh
# UserPromptSubmit フック。ステータスラインが書き出したコンテキスト量が
# しきい値を超えていたら、/save を勧める文を一度だけ注入する。
# compaction などで量がしきい値を下回ったら印を消し、次に超えたときにまた注入する。
threshold=${SAVE_NUDGE_TOKENS:-600000}
sid=$(jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
ctx="$HOME/.claude/statusline/ctx/$sid"
mark="$HOME/.claude/save/.nudged-$sid"
[ -f "$ctx" ] || exit 0
tokens=$(cat "$ctx" 2>/dev/null)
case "$tokens" in ''|*[!0-9]*) exit 0 ;; esac
if [ "$tokens" -lt "$threshold" ]; then
  rm -f "$mark"
  exit 0
fi
[ -f "$mark" ] && exit 0
mkdir -p "$(dirname "$mark")"
: >"$mark"
k=$((tokens / 1000))
jq -n --arg msg "コンテキストは約${k}Kトークンで、/save の推奨しきい値（$((threshold / 1000))K）を超えている。いまの応答の最後に、ユーザーへ /save → /compact の実行を一行で勧める。" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$msg}}'
