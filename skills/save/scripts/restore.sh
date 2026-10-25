#!/bin/sh
# SessionStart フック（matcher: compact）。/save の記録があれば compaction 後の文脈に注入する。
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
rec="$HOME/.claude/save/$sid.md"
[ -f "$rec" ] || exit 0
age=$(( ($(date +%s) - $(stat -f %m "$rec")) / 60 ))
body=$(python3 -I -c "import sys; print(open(sys.argv[1], encoding=\"utf-8\", errors=\"replace\").read()[:9000])" "$rec")
head="compaction 前に /save で書いた記録（${rec}、${age}分前に更新）。記録は未検証の手がかりで、再開前に git と照合する手順は ~/.claude/skills/save/SKILL.md の先頭にある。"
jq -n --arg ctx "$head

$body" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
