# CLAUDE.md の例: i-have-adhd と japanese-tech-writing の併用

i-have-adhd と japanese-tech-writing は、どちらもエージェントの返答の書き方を決めるので、併用すると規則がぶつかる。i-have-adhd は返答の先頭に次の行動を置き、手順を番号付きの箇条書きにさせる。japanese-tech-writing は段落を論証の単位とするパラグラフライティングを求める。

この例では、`~/.claude/CLAUDE.md` に優先順位を一文で書いて衝突を解く。返答の構成（何を先頭に置くか、番号を振るか、箇条書きにするか）は i-have-adhd に従わせ、文の書き方（語の選び方、論証、空句や翻訳調の禁止）は japanese-tech-writing に従わせる。

## 前提

- i-have-adhd を [recommendation.md](../recommendation.md#i-have-adhd) の手順でプラグインとして入れている。プラグインの SessionStart フックが、毎セッションの開始時に規則を注入する。
- japanese-tech-writing を `~/.claude/skills/japanese-tech-writing` に入れている。

## `~/.claude/CLAUDE.md` に足す部分

```markdown
## 日本語の文章規範（常時）
チャットの返答の構成（次の行動を先頭に置く、番号付きの手順、箇条書き）は i-have-adhd を優先し、文の書き方（語の選び方、論証、空句・翻訳調の禁止）に japanese-tech-writing を使う。

@~/.claude/skills/japanese-tech-writing/SKILL.md
```

最後の行は Claude Code の import 記法で、`SKILL.md` の本文を CLAUDE.md の一部として毎セッション読み込ませる。スキルとして入れただけでは、エージェントが日本語の技術文書を書くと判断したときにしか規範が読み込まれない。チャットの返答はこの判断に当たらないことが多い。

SessionStart フックで注入しないのは、フックの出力の上限（10,000 文字）に近いためである。`SKILL.md` はフロントマターを除いて 9,339 文字あり、規則を足すと上限を超えて切り詰められる。

## 確かめ方

新しいセッションで、japanese-tech-writing の規則の悪い例を一つ引用させる。引用できれば読み込まれている。
