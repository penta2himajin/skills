#!/bin/sh
# SessionStart フック。compact では同じセッションの記録を、startup / resume / clear では
# finish.sh が置いた印（save-pending）の記録を一度だけ、compaction 後や新しいセッションの文脈に注入する。
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)
t=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$sid" ] && [ -n "$t" ] || exit 0
proj=$(dirname "$t")
if [ "$src" = compact ]; then
  rec="$proj/save/$sid.md"
  how="compaction 前に /save で書いた記録"
else
  flag="$proj/save-pending"
  [ -f "$flag" ] || exit 0
  rec=$(cat "$flag")
  rm -f "$flag"
  how="前のセッションが /save で書いた記録。このセッションで /save するときは、この記録を複製して新しい記録の出発点にする"
fi
[ -f "$rec" ] || exit 0
python3 -I -c '
import json, os, sys, time
rec, how, src = sys.argv[1:4]
age = int((time.time() - os.path.getmtime(rec)) // 60)
if src != "compact" and age > 1440:
    sys.exit(0)  # 24 時間より古い印の記録は注入しない
body = open(rec, encoding="utf-8", errors="replace").read()[:9000]
head = f"{how}（{rec}、{age}分前に更新）。記録は未検証の手がかりで、再開の前に照合する手順は save スキルの「記録から再開した場合」にある。"
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": head + "\n\n" + body}}, ensure_ascii=False))
' "$rec" "$how" "$src"
