"""agy の校正案（structured_output.edits）を、Claude の判定を反映して原文のコピーに適用する。
grok スキルの校正モードも、extract_edits.py が書いた {"edits": [...]} をこれに渡す。

usage: python3 -I apply_edits.py <原文> <agy-out.json|edits.json> <decisions.json|-> <出力先>

decisions.json:
  {"reject": {"<id>": "不採用の理由"},
   "override": {"<id>": {"new": "差し替え後の文字列", "reason": "修正の理由"}}}

出力先が既にあれば書かない。HTML なら適用前後でタグ構造が一致することを確かめ、
一致しなければ書かずに終了コード 1 で終わる。
"""
import json
import os
import sys
from html.parser import HTMLParser


class Skeleton(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.tags, self.texts, self.raw = [], [], False

    def handle_starttag(self, t, a):
        self.tags.append(("S", t, tuple(a)))
        self.raw = t in ("script", "style")

    def handle_endtag(self, t):
        self.tags.append(("E", t))
        self.raw = False

    def handle_startendtag(self, t, a):
        self.tags.append(("SE", t, tuple(a)))

    def handle_comment(self, d):
        self.tags.append(("C", d))

    def handle_data(self, d):
        if self.raw:
            self.tags.append(("RAW", d))
        elif d.strip():
            self.texts.append(d.strip())


def skeleton(html):
    p = Skeleton()
    p.feed(html)
    return p


def main():
    src, agy_out, decisions_path, dst = sys.argv[1:5]
    if os.path.exists(dst):
        sys.exit(f"出力先が既にある: {dst}")
    text = open(src, encoding="utf-8").read()
    out = json.load(open(agy_out, encoding="utf-8"))
    edits = (out.get("structured_output") or out)["edits"]
    dec = {"reject": {}, "override": {}}
    if decisions_path != "-":
        dec.update(json.load(open(decisions_path, encoding="utf-8")))

    is_html = src.lower().endswith((".html", ".htm"))
    result, rows, errors = text, [], []
    for e in edits:
        i = str(e["id"])
        if i in dec["reject"]:
            rows.append((i, "不採用", e["old"], e["new"], dec["reject"][i]))
            continue
        new, how, why = e["new"], "採用", e["reason"]
        if i in dec["override"]:
            new, how, why = dec["override"][i]["new"], "修正採用", dec["override"][i]["reason"]
        n = result.count(e["old"])
        if n != 1:
            errors.append(f"id={i}: old が {n} 箇所に一致")
            continue
        if is_html and any(c in s for s in (e["old"], new) for c in "<>"):
            errors.append(f"id={i}: old/new にタグが含まれる（テキストノード内に限る規則に反する）")
            continue
        result = result.replace(e["old"], new)
        rows.append((i, how, e["old"], new, why))

    if is_html:
        a, b = skeleton(text), skeleton(result)
        if a.tags != b.tags:
            errors.append("タグ構造が変わった")
        if len(a.texts) != len(b.texts):
            errors.append(f"テキストノード数が変わった: {len(a.texts)} -> {len(b.texts)}")

    for r in rows:
        print("\t".join(r))
    counts = {k: sum(1 for r in rows if r[1] == k) for k in ("採用", "修正採用", "不採用")}
    print(f"\n案 {len(edits)} 件: {counts}, エラー {len(errors)} 件", file=sys.stderr)
    for m in errors:
        print("ERROR", m, file=sys.stderr)
    if errors:
        sys.exit(1)
    open(dst, "w", encoding="utf-8").write(result)
    print(f"書き出し: {dst}", file=sys.stderr)


main()
