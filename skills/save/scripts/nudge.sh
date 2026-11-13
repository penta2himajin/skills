#!/bin/sh
# UserPromptSubmit フック。ステータスラインが書き出したコンテキストの使用率がしきい値（既定 50%）を超えたら、
# そのセッションを自動保存モードにし、compaction か /clear まで毎ターン、記録の更新と /compact・/clear の推奨を指示する。
# モードはフラグファイル .over-<セッション ID> で表す。compaction では restore.sh が消し、/clear ではセッション ID が変わる。
# ターンの開始時刻を .turn-<セッション ID> に残し、guard.sh（Stop）が記録の更新漏れの判定に使う。
threshold=${SAVE_NUDGE_PERCENT:-50}
sid=$(jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
dir="$HOME/.claude/save"
over="$dir/.over-$sid"
pct=$(cat "$HOME/.claude/statusline/ctx/$sid.pct" 2>/dev/null)
case "$pct" in ''|*[!0-9]*) pct= ;; esac
if [ ! -f "$over" ]; then
  [ -n "$pct" ] && [ "$pct" -ge "$threshold" ] || exit 0
  mkdir -p "$dir" && printf '%s\n' "$pct" >"$over"
  first=1
fi
: >"$dir/.turn-$sid"
if [ -n "${first:-}" ]; then
  msg="コンテキストの使用率が${pct}%で、しきい値（${threshold}%）を超えた。このセッションは compaction か /clear まで自動保存モードになる。このターンでは、ユーザーの依頼に答えたうえで、save スキルを起動して記録を書き、手順 5 のコミットまで行う。"
else
  msg="自動保存モード（コンテキストの使用率は${pct:-?}%）。このターンの作業を終えたら、save スキルの「書き出しの手順」の 1、3〜5 に従い、記録を Edit で更新してコミットする。記録に直すことがなくても、手順 5 のコミットは実行する。"
fi
msg="${msg}応答の最後に、/compact か /clear の実行を勧める一行を書く。手順 6 の2行の返答は使わない。"
jq -n --arg msg "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$msg}}'
