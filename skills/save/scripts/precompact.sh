#!/bin/sh
# PreCompact フック。標準出力が compaction の要約への追加指示になる。
# 文書化されていない挙動で、Claude Code 2.1.308 で確認した。使えなくなっても、通常の要約に戻るだけである。
# 標準出力があると事前に用意された要約が使われなくなるため、compaction は遅くなる。
d=$(cd "$(dirname "$0")/.." && pwd)
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
t=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
rec="$(dirname "${t:-.}")/save/$sid.md"
if [ -n "$sid" ] && [ -n "$t" ] && [ -f "$rec" ]; then
  echo "要約は、作業を再開するための記録として、下の書き方の規則と記録の構成に従って書く。/save の記録（$rec）は compaction の後に再注入されるので、記録にあることは繰り返さない。記録の保存時刻より後に起きたこと（新しい事実・決定・失敗、終えた項目、次の一手の変化）と、記録と食い違う点だけを、記録と同じ節の構成で書く。"
else
  echo "要約は、作業を再開するための記録として、下の書き方の規則と記録の構成に従って書く。記録ファイルを書く手順は飛ばし、記録の本文だけを要約として出す。"
fi
echo
sed -n '/^## 書き方の規則/,/^## 作業中の常設ルール/p' "$d/SKILL.md" | sed '$d'
echo "## 記録の構成"
echo
cat "$d/references/template.md"
