# おすすめのスキル

ほかの人が公開しているスキルのうち、手元に入れて使っているものの一覧。
中身はこのリポジトリにコピーせず、出典から直接入れる。コマンドは 2026-10-26 時点の各リポジトリの README に従った。

## 特におすすめ：mattpocock/skills の grilling と research

出典: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）

| スキル | 内容 |
|---|---|
| [grilling](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) | 計画や判断について、決定の依存関係を木にたどりながら、答えの出せる質問を一巡ずつユーザーに問い詰める |
| [research](https://github.com/mattpocock/skills/blob/main/skills/engineering/research/SKILL.md) | 調べものをバックグラウンドのエージェントに任せ、一次情報だけを出典付きで Markdown にまとめさせる |

この2つだけを入れる場合:

```sh
npx skills add mattpocock/skills --skill grilling --skill research -g
```

リポジトリには、ほかにも 30 余りのスキルがある。まとめて入れる場合は Claude Code のプラグインとして入れる。

```sh
claude plugin install mattpocock-skills@claude-plugins-official
```

## i-have-adhd

出典: [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd)（MIT）

応答の先頭に次の行動を置き、手順に番号を振り、前置きと締めの挨拶を省くよう、エージェントの出力の形を決める。プラグインとして入れると、セッションの開始時に規則が注入される。

```sh
claude plugin marketplace add ayghri/i-have-adhd
claude plugin install i-have-adhd@i-have-adhd
```

## imozuru

出典: [MaryCache/imozuru](https://github.com/MaryCache/imozuru)（MIT）

知らない分野の用語、中心の人、発信の場を特定し、引用と著者をたどって原文（論文、個人の記事、動画の字幕）を要約せずに保存する。保存した場の新着を RSS で確認するモードもある。

```sh
claude plugin marketplace add MaryCache/imozuru
claude plugin install imozuru@imozuru
```

Claude Code 以外のエージェントに入れる場合は `npx skills add MaryCache/imozuru` を使う。
