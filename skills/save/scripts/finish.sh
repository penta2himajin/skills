#!/bin/sh
# /save の補助。path: 記録ファイルのパスを出力する。commit: 読み戻し待ちを表すファイル（save-pending）を置き、記録を git にコミットする。
# 記録はセッションの transcript と同じディレクトリ（~/.claude/projects/<作業ディレクトリ>/）の save/ に置く。
# transcript の場所から決めるので、セッション中に cd しても場所は変わらない。
cmd=$1 sid=$2
t=$(ls "$HOME"/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -1)
[ -n "$t" ] || { echo "セッション $sid の transcript が見つからない" >&2; exit 1; }
proj=$(dirname "$t")
rec="$proj/save/$sid.md"
case $cmd in
path)
  mkdir -p "$proj/save" && echo "$rec"
  ;;
commit)
  [ -f "$rec" ] || { echo "記録がない: $rec" >&2; exit 1; }
  printf '%s\n' "$rec" >"$proj/save-pending"
  if [ ! -d "$proj/.git" ]; then
    git -C "$proj" init -q || exit 1
    printf '*.jsonl\n????????-????-????-????-????????????/\n' >"$proj/.git/info/exclude"
  fi
  grep -qx save-pending "$proj/.git/info/exclude" || echo save-pending >>"$proj/.git/info/exclude"
  git -C "$proj" add -- save &&
    { git -C "$proj" diff --cached --quiet || git -C "$proj" commit -qm "save: $(echo "$sid" | cut -c1-8) ${3:-}"; } &&
    git -C "$proj" log --oneline -1
  ;;
*)
  echo "usage: finish.sh path|commit <session_id> [summary]" >&2
  exit 1
  ;;
esac
