# おすすめのスキル

ほかの人が公開しているスキルのうち、手元に入れて使っているものの一覧。
中身はこのリポジトリにコピーせず、出典から直接入れる。コマンドは 2026-10-26 時点の各リポジトリの README に従った。
例外は research と japanese-tech-writing で、微調整を加えた版をこのリポジトリに置いている（[research の節](#research-を微調整した版)、[japanese-tech-writing の節](#japanese-tech-writing)）。

## 特におすすめ：mattpocock/skills の grilling と research

出典: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）

| スキル | 内容 |
|---|---|
| [grilling](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) | 計画や判断を構成する決定どうしの依存関係を木構造で整理し、前提が決まった決定について、一巡ずつまとめてユーザーに問う |
| [research](https://github.com/mattpocock/skills/blob/main/skills/engineering/research/SKILL.md) | 調べものをバックグラウンドのエージェントに任せ、一次情報に当たって調べた結果を、主張ごとに出典を付けて Markdown にまとめさせる |

この2つだけを入れる場合:

```sh
npx skills add mattpocock/skills --skill grilling --skill research -g
```

### research を微調整した版

このリポジトリの [`skills/research`](skills/research/SKILL.md) は、research に、調べものを任されたエージェント向けの規則を3つ足した版である。ライセンスは元と同じ MIT で、ディレクトリに元のリポジトリの [LICENSE](skills/research/LICENSE) を置いた。

- research を実行しているエージェントは、research を再び呼ばない。読むだけの補助の問いは1段まで別のエージェントに渡してよいが、ファイルを書くのは本人だけとする。
- 見つからなかったと報告するときは、どこを探したかと、読むなと言われたものを書く。
- 書いた後、判断の根拠になる主張（要約とその主な数値）を、別のコンテキストで、できれば別のモデルに、引用した出典と照合させる。

```sh
npx skills add penta2himajin/skills --skill research -g
```

リポジトリには、ほかにも 30 余りのスキルがある。まとめて入れる場合は Claude Code のプラグインとして入れる。

```sh
claude plugin install mattpocock-skills@claude-plugins-official
```

## i-have-adhd

出典: [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd)（MIT）

応答の先頭に次の行動を置き、手順に番号を振り、前置きと締めの挨拶を省くよう、エージェントの応答の構成を決める。プラグインとして入れると、プラグインの SessionStart フックがセッションの開始時に規則を注入する。

```sh
claude plugin marketplace add ayghri/i-have-adhd
claude plugin install i-have-adhd@i-have-adhd
```

## ponytail

出典: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)（MIT）

コードを書くときに、要件を満たす最小の解を選ばせる。新しく書く前に、その機能が本当に要るか、既存のコード・標準ライブラリ・プラットフォームの機能で足りるかを順に確かめさせ、頼まれていない抽象化や依存の追加を避けさせる。プラグインとして入れると、プラグインの SessionStart フックがセッションの開始時に規則を注入する。

```sh
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
```

## imozuru

出典: [MaryCache/imozuru](https://github.com/MaryCache/imozuru)（MIT）

知らない分野の用語、主要な人物、情報源を特定し、引用と著者をたどって原文（論文、個人の記事、動画の字幕）を要約せずに保存する。記録した情報源の新着を、RSS で取得して一覧にするモードもある。

```sh
claude plugin marketplace add MaryCache/imozuru
claude plugin install imozuru@imozuru
```

Claude Code 以外のエージェントに入れる場合は `npx skills add MaryCache/imozuru` を使う。

## japanese-tech-writing

出典: [k16shikano 氏の gist](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)（Unlicense）

日本語の技術文書を書くときと推敲するときの文章規範。パラグラフライティング、論証の厳密さ、読み手の負荷の管理、LLM が生成しがちな空句や翻訳調の比喩の禁止などを定める。

### ライセンス

元の gist は public で、k16shikano 氏は自身の public gist すべてに Unlicense を適用すると宣言している。以下は[ライセンス宣言の gist](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063) の `Readme.ja.md` からの引用である。

> k16shikanoのpublic gistには、すべてUnlicenseを適用します。
> つまり、著作権上の権利をパブリックドメインに献呈する意思を示します。
> 日本のように完全なパブリックドメイン化が明確でない法域では、実務上はパブリックドメイン相当の利用を許すものとします。

このリポジトリの [`skills/japanese-tech-writing`](skills/japanese-tech-writing/SKILL.md) は、改変した部分も含めて Unlicense とする。ディレクトリに [LICENSE](skills/japanese-tech-writing/LICENSE) として Unlicense の本文を置いた。リポジトリのほかの部分の MIT ライセンスは、このディレクトリには適用しない。

### このリポジトリの版で加えた変更

gist の 2026-09-09 の版（リビジョン `8f2d576`）に、次の微調整を加えた。

- 術語の選び方の規則に、カタカナや英語のまま定着した術語や、漢語で定着した訳語を、一般語や和語に言い換えない旨を追加した（client secret は「クライアントの秘密」ではなく「クライアントシークレット」、notification は「知らせ」ではなく「通知」）。
- 定義していない造語で区分を名付けない規則を追加した。
- 平易さのために語を言い換えることを禁じる項目を追加した。定着していない連用形の名詞化（「返信の確かめ」）、「の」による複合語の分解（「設定の画面」）、和語の動詞（「足す」「出す」）が対象である。翻訳調の比喩の例にも、have の直訳（「再送を持たない」）を追加した。
- 「推測を比喩で書かない」の節を追加した。「読み」「見立て」「肌感」のような比喩の名詞で推測を書かず、「推測」「仮説」のような普通の語で主張の地位を示す。
- 上の節に合わせて、`description` にその節を示す句を追加した。

元の版を使う場合は、gist の `SKILL.md` をスキルのディレクトリ（Claude Code なら `~/.claude/skills/japanese-tech-writing/`）に置く。このリポジトリの版は次のコマンドで入る。

```sh
npx skills add penta2himajin/skills --skill japanese-tech-writing -g
```
