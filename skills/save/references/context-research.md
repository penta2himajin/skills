# LLM のコンテキスト運用に関する研究調査（/refresh 設計用）

調査日: 2026-10-20

## この資料の範囲と読み方

- 目的: セッションの記録をファイルに書き出し、compaction 後もタスクを安定して続けるための Skill `/refresh` を設計する。そのための根拠を集める。
- 対象: 長文脈での性能劣化（lost in the middle、context rot）、エージェントの文脈圧縮・要約、長期記憶、構造化メモ、復元可能な圧縮。2024〜2026 年の研究を優先した。
- 出典の扱い:
  - 論文は arXiv API で題名・著者・投稿日・ID を確かめたものだけを載せた。数値は論文本体（arXiv HTML 版）で確かめ、表・節・図の番号を添えた。abstract だけで確かめた数値には「(Abstract)」と書いた。
  - 査読状況は arXiv の comment／journal-ref に書かれている場合だけ記した。記載のないものは査読前のプレプリントとして扱う。2026 年の論文は大半がプレプリントで、単著や n=10 程度の小規模研究も多い。
  - 研究機関の技術報告（Chroma）は一次資料として扱う。Anthropic と Manus の技術ブログは論文ではないが、Claude Code の実装と「restorable compression」という用語の一次情報源なので、別枠（§4.1、§4.2）で「実務報告（査読なし）」と明記して載せた。
  - 論文中のモデル名（例: GPT-5.6 Luna、Qwen3.8-27B）は論文の表記どおりに書いた。

---

## 0. 要旨

1. 長い入力では、情報が入っていても使われない。中央に置いた情報は特に使われにくい（Lost in the Middle）。入力が長いだけで、検索が完全でも精度は下がる（Context Length Alone Hurts）。語の一致がない質問では、32K で 13 モデル中 11 モデルが短文脈時の半分以下に落ちる（NoLiMa）。
2. エージェントでは、文脈の長さよりステップ数のほうが劣化を強く左右するという報告がある（How Fast Do Agents Rot?）。長い文脈を切り詰めても劣化は止まらない。
3. LLM 要約は、単純な observation masking（古いツール出力をプレースホルダに置き換える方法）と比べてコスト効率で上回らない。要約を挟むと軌跡が約 15% 長くなる（Complexity Trap）。
4. 要約で失われやすいと実測された情報は次のとおり。日付・時刻（保存率 3%）、識別子・変数・認証トークン、ユーザーが会話の中だけで決めたルール（commitments）、直近のやり取りの影響力、失敗した試みとエラー。
5. 要約は情報を落とすだけでなく、根拠のない内容も追加する。構造化圧縮器の失敗の 83% は、要約の特定の記述を実行したことに遡れた。根拠のない記述の割合は「未対応のユーザー依頼」欄で 86%、「Open TODO」欄で 68% と高く、「識別子」欄では 3% と低い（SJC）。
6. 全文の書き換えを繰り返すと文脈が崩壊する。18,282 トークンが 1 ステップで 122 トークンになり、精度は適応なしの基準値を下回った（ACE の context collapse）。ID 付きの項目に差分を追加していく方式（delta 更新）がこれを避ける。
7. ファイルに状態を外出しし、毎ステップそこから文脈を組み直すエージェントは、圧縮だけで続けるエージェントより長期のカバー率が大幅に高い（InfiAgent）。外部チェックリストを終了前に確かめさせると、長文脈での合格が 5/10 から 10/10 に上がった（ただし n=10）。
8. 復元可能な圧縮（原文はファイルや store に残し、文脈にはパスや索引だけを残す）は、Manus と Anthropic の実務報告で提唱され、Memex・LCM・ACM・transparent-compact で実装・評価されている。ただし「要約のみ」と同条件で比べた対照実験はまだ少ない。

---

## 1. 長いコンテキストでの性能劣化

### 1.1 Lost in the Middle: How Language Models Use Long Contexts

- 書誌: Nelson F. Liu, Kevin Lin, John Hewitt ほか。2023 年 7 月投稿、TACL 掲載（arXiv の注記による）。arXiv:2307.03172
- 主張: 関連情報が入力の先頭か末尾にあると精度が高く、中央にあると大きく下がる（U 字型）。
- 手法: 複数文書 QA とキー・バリュー検索で、正解の位置と文書数を変えて測った。
- 結果:
  - GPT-3.5-Turbo、20 文書の場合（§2.3、Figure 5、Appendix G.2 Table 6）。正解が先頭なら 75.8%、中央（index 9）なら 53.8%、末尾なら 63.2%。文書を与えない closed-book は 56.1%（Table 1）で、中央に置くと文書なしより悪い。
  - 質問をデータの前後両方に置く query-aware contextualization（§4.2、Figure 9）で、キー・バリュー検索はほぼ全モデルで満点近くになった。複数文書 QA への効果は小さい。
  - 取得文書を 20 から 50 に増やしても、精度は GPT-3.5-Turbo で約 1.5%、Claude-1.3 で約 1% しか上がらない（§5、Figure 11）。
- 限界: 2023 年時点のモデルで測っている。後述の Chroma 報告では、needle の位置の影響は目立たなかった。
- 出典: https://arxiv.org/abs/2307.03172

### 1.2 Found in the Middle: Calibrating Positional Attention Bias Improves Long Context Utilization

- 書誌: Cheng-Yu Hsieh, Yung-Sung Chuang, Chun-Liang Li ほか。2024 年、ACL Findings 2024。arXiv:2406.16008
- 主張: lost in the middle は、注意そのものの U 字型バイアスと結びついている。先頭と末尾のトークンは、関連性と無関係に高い注意を受ける。
- 結果: このバイアスを補正すると、RAG の性能が既存手法より最大 15 ポイント上がった（Abstract）。
- 限界: モデル内部への介入なので、プロンプト側では使えない。位置バイアスの原因を示す根拠として参照する。
- 出典: https://arxiv.org/abs/2406.16008

### 1.3 RULER: What's the Real Context Size of Your Long-Context Language Models?

- 書誌: Cheng-Ping Hsieh, Simeng Sun, Samuel Kriman ほか。2024 年、COLM 2024。arXiv:2404.06654
- 主張: 単純な needle-in-a-haystack（NIAH）ではほぼ満点でも、needle の種類や数を増やしたり、多段追跡や集約を求めたりすると大きく落ちる。
- 結果: 17 モデル・13 タスクで評価した。32K 以上を公称するモデルのうち、32K で満足な性能を保てたのは半数だった（Abstract）。
- 限界: 合成タスクで測っている。
- 出典: https://arxiv.org/abs/2404.06654

### 1.4 NoLiMa: Long-Context Evaluation Beyond Literal Matching

- 書誌: Ali Modarressi, Hanieh Deilamsalehy, Franck Dernoncourt ほか。2025 年 2 月。arXiv:2502.05167
- 主張: 質問と needle の間に語の一致がないと、長文脈での検索は急に難しくなる。
- 結果:
  - 128K 以上を公称する 13 モデルのうち、11 モデルが 32K で基準スコアの半分以下になった。
  - GPT-4o は基準 99.3% から 32K で 69.7% に下がる。論文の定義による有効長は 8K で、表中のモデルで最良だった。
  - 語の一致を加えると、Llama 3.3 70B の 2 ホップ精度は 32K で 25.9% から 87.2% に上がる。
  - 質問のキーワードを含むが答えとは無関係な文（distractor）を加えると、GPT-4o の有効長は 1K まで縮む。
  - CoT は少しだけ効く（Llama 3.3 70B の 2 ホップで 25.9% から 34.3%）。
- 含意: 記録の見出しや項目名は、後で問われる語と同じ語で書くと拾われやすい。
- 出典: https://arxiv.org/abs/2502.05167

### 1.5 Same Task, More Tokens: the Impact of Input Length on the Reasoning Performance of LLMs

- 書誌: Mosh Levy, Alon Jacoby, Yoav Goldberg。2024 年、ACL 2024。arXiv:2402.14848
- 主張: 同じ問題に無関係な水増し（padding）を加えるだけで、推論性能は技術的な最大長よりずっと短い長さから下がる（Abstract）。
- 出典: https://arxiv.org/abs/2402.14848

### 1.6 Context Length Alone Hurts LLM Performance Despite Perfect Retrieval

- 書誌: Yufeng Du, Minyang Tian, Srikanth Ronanki ほか。2025 年 10 月、プレプリント。arXiv:2510.05381
- 主張: 必要な情報を完全に取り出せても、入力が長いだけで解答精度は下がる。
- 結果:
  - Llama-3.1-8B は 30K で MMLU 1000 問中 970 問を正確に取り出せたが、精度は 24.2% 下がった（§3.2、Figure 3、Table 6）。
  - 空白トークンで水増ししても下がる。下がり幅は 30K で少なくとも 7%、VarSum では 48%（§4.1、Table 7）。注意を完全にマスクしても 7.9% 以上下がる（§4.2、Table 3）。
  - 緩和策は「まず関係する証拠を書き写させ、その短いプロンプトで解かせる」（§5、Tables 4–5）。Mistral の合成 GSM8K（26K）は 35.5% から 66.7% に上がった。
- 限界: オープンモデル 2 種、クローズドモデル 3 種、4 タスクでの評価。緩和策は検索が完全であることを前提にしている。
- 出典: https://arxiv.org/abs/2510.05381

### 1.7 Context Rot: How Increasing Input Tokens Impacts LLM Performance（Chroma 技術報告）

- 書誌: Kelly Hong, Anton Troynikov, Jeff Huber。Chroma Technical Report、2025-07-14。
- 主張: モデルは文脈を均一には使わず、入力が長くなるほど信頼性が下がる。
- 手法と結果: Claude Opus 4、GPT-4.1、Gemini 2.5 Pro、Qwen3 など 18 モデルで測った。
  - needle と質問の類似度が低いほど、長さによる劣化が速い。needle の位置には目立った影響がなかった。
  - distractor が 1 つあるだけで精度が下がり、4 つでさらに下がる。Claude は回答を控えることが多く、GPT は幻覚を生成することが多かった。
  - haystack（needle を埋め込む周囲の文章）は、文の順序を壊したもののほうが、論理的につながったものより全 18 モデルで成績が良かった（"Haystack Structure" 節）。著者自身も「意外」と書いている。
  - LongMemEval の 306 問では、必要部分だけの約 300 トークンの入力が、約 113k トークンの全入力より大幅に良かった。
- 結論（"Conclusion" 節）: 情報が文脈に入っているだけでは足りず、どう提示するかが重要だとする。
- 限界: 現実のタスクはもっと複雑で、劣化はさらに大きい可能性がある。メカニズムは未解明（"Limitations & Future Work" 節）。
- 出典: https://www.trychroma.com/research/context-rot

### 1.8 LongMemEval: Benchmarking Chat Assistants on Long-Term Interactive Memory

- 書誌: Di Wu, Hongwei Wang, Wenhao Yu ほか。2024 年、ICLR 2025。arXiv:2410.10813
- 主張: 長期記憶に必要な能力は 5 つある。情報抽出、複数セッションにまたがる推論、時間推論、知識の更新、回答の保留。
- 結果: 商用アシスタントと長文脈 LLM は、長い対話をまたいで情報を記憶させると精度が 30% 落ちる（Abstract）。改善策として、セッションの分解、事実で拡張したキー、時間を考慮したクエリ拡張を提案している。
- 出典: https://arxiv.org/abs/2410.10813

### 1.9 LLMs Get Lost In Multi-Turn Conversation

- 書誌: Philippe Laban, Hiroaki Hayashi, Yingbo Zhou ほか。2025 年 5 月。arXiv:2505.06120
- 主張: 指示を複数ターンに分けて与えると、平均で 39% 性能が落ちる（§6.1）。落ちる主な理由は能力の低下ではなく、ばらつきの増大である。
- 結果:
  - 最良時の性能（aptitude）の低下は約 16% にとどまり、ばらつき（unreliability）は約 112% 増えた（§6.2、Figure 6）。
  - 原因として次の 4 つを挙げている（App. F）。
    - 情報が揃う前に答えを出す。
    - 以前の誤った答えに頼る。
    - 最初と最後のターンに偏り、中間のターンを落とす（loss-of-middle-turns）。
    - 冗長な応答が増える。
  - 緩和策の比較（§7.1、Table 2）。GPT-4o は Full（一括で指示）93.0、Sharded（分割）59.1、Recap（最後に要点を再掲）76.6、Snowball（毎ターン再掲）65.3 だった。一括に書き直した Concat は 90.9 で、Full に近い。
  - 推奨: 会話を一度まとめさせ、その要約で新しい会話を始める（§7.4）。
- 含意: 分散した指示を 1 か所にまとめ直すと、性能はほぼ回復する。/refresh の記録はこの「まとめ直し」にあたる。
- 出典: https://arxiv.org/abs/2505.06120

### 1.10 Positional Failures in Long-Context LLMs: A Blind Spot in Reasoning Benchmarks

- 書誌: Chuyifei Zhang, Hongyu Cui, Xiaowen Huang ほか。2026 年 5 月、プレプリント。arXiv:2605.23170
- 主張: 推論ベンチマークは課題の位置を制御していない。課題を中央に置くと大きく落ちるモデルがある。
- 結果（Abstract）:
  - MiMo-v2-Flash は、64K で課題を中央に置くと 88 ポイント落ちた。新しいリリースでは落ち幅が小さく、64K で 4 モデル中 3 モデルが末尾配置との差 ±6 ポイント以内だった。
  - 8K で課題の写しを末尾に加えると、9 モデルすべてで中央配置の精度が末尾配置の ±4 ポイント以内に戻った。
  - 中央配置の誤りの 76% は、周囲の filler の答えと一致していた（末尾配置では 22%）。
- 含意: 2026 年のモデルでも位置の影響は残る。重要事項を末尾に再掲する方法は有効である。
- 出典: https://arxiv.org/abs/2605.23170

### 1.11 When and How Context Rot Appears in Coding Agents: A White-Box Study of Agent Skills in Code Auditing

- 書誌: Yue Xue。2026 年 7 月、プレプリント（単著）。arXiv:2607.17937
- 主張: Agent Skill を読み込んでも、長い軌跡の中で要件がすべて保たれるとは限らない。
- 結果（Table 2、Table 7、§5.5.1）:
  - Codex（gpt-5.4-mini）の合格は、きれいな文脈（約 11K 文字）で 8/10、長い文脈（約 30 万文字）で 3/10 だった。長い文脈の中身が関連する内容でも無関係な内容でも 3/10 で同じ。
  - 要件のカバー率は長文脈でも 92% 以上ある。少数の取りこぼしで成果物全体が不合格になる。
  - 終了前に 24 項目の詳細チェックリストを確かめさせると 10/10、一般的な自己点検の指示では 5/10 だった（Fisher p=0.0325）。
  - 失敗 44 件のうち 38 件で、最終メッセージが成功・完了を主張していた（§5.4.1）。
- 推奨（§6.5–6.6）: 背景と証拠は取り出せる場所に置く。未完了の重要な義務は、小さく、明示的に、transcript の外に置き、独立に確かめられる形にする。ツール出力が期待と食い違ったら、関連項目を再び開く。
- 限界: n=10 の比較で、著者自身が効果を過大評価しうると書いている。2 つ目のタスクでは劣化しなかった。
- 出典: https://arxiv.org/abs/2607.17937

### 1.12 How Fast Do Agents Rot? An Empirical Study of Long-Horizon Degradation in LLM Agents for Production Decision-Making

- 書誌: Shubhra Mittal。2026 年 8 月、プレプリント（単著）。arXiv:2609.01660
- 主張: タスクの成功率は、1 ステップあたりの信頼度をパラメータとする幾何分布に従う。劣化を左右するのは文脈の長さではなくステップ数である。
- 結果（Abstract）:
  - エージェント課題では、全モデルが 16 ステップ以内にほぼ 100% の成功からほぼ 0 まで落ちた（n=10,664 軌跡）。
  - 文脈ウィンドウを制限すると、減衰はむしろ急になった（logit 傾き -0.69 対 -0.44、p=3×10⁻⁶）。
- 含意: 文脈を短くするだけでは不十分である。ステップごとの誤りを、外部の状態ファイルと検証で断ち切る必要がある。
- 出典: https://arxiv.org/abs/2609.01660

### 1.13 Diagnosing and Mitigating Context Rot in Long-horizon Search

- 書誌: Shijie Xia, Yikun Wang, Zhen Huang ほか。2026 年 6 月、プレプリント。arXiv:2606.29718
- 主張: 文脈が長くなると、ウィンドウを使い切るずっと前に諦めたり、不確かな誤答を返したりする（premature termination）。その率は文脈長と正の相関がある。
- 結果（Abstract）: 3 分類 7 種の文脈管理手法を比べると、どれも本質的には premature termination を減らして探索を延ばす手法だった。
- 出典: https://arxiv.org/abs/2606.29718

### 1.14 小括: どの位置・どの形式の情報が保たれやすいか

- 位置: 先頭と末尾は保たれやすく、中央は落ちやすい（1.1、1.2、1.10）。課題の写しを末尾に置くと、中央配置の損失はほぼ消える（1.10）。質問をデータの前後両方に置くと効く（1.1 §4.2）。複数ターンの会話でも中間のターンが落ちる（1.9）。
- 形式:
  - 質問と同じ語で書かれた情報は拾われやすい（1.4）。
  - 必要部分だけを抜き出した短い入力は、全入力より大幅に良い（1.6、1.7）。
  - 似ているが無関係な記述（distractor）は害が大きい（1.4、1.7）。古くなった記述を記録に残すと distractor になる。
- 長さ: 長さそのものが害になる（1.5、1.6）。ただしエージェントではステップ数の影響のほうが大きいという報告もある（1.12）。
- 未解決: 論理的につながった文章のほうが悪いという Chroma の結果（1.7）は、まだ説明されていない。記録ファイルの書き方に直接は当てはめない。

---

## 2. エージェントの文脈圧縮・要約の手法と比較

### 2.1 The Complexity Trap: Simple Observation Masking Is as Efficient as LLM Summarization for Agent Context Management

- 書誌: Tobias Lindenbauer, Igor Slinko, Ludwig Felder ほか。2025 年 8 月。ワークショップ "Deep Learning for Code in the Agentic Era" 採択。arXiv:2508.21433
- 主張: 古い観測（ツール出力）をプレースホルダに置き換えるだけの observation masking は、LLM 要約と同等以上に効率がよい。
- 手法: SWE-agent で SWE-bench Verified を解かせ、5 つのモデル構成で比べた。masking は直近 M=10 ターンを全文で残す。
- 結果:
  - コスト削減は masking が 50.9〜57.1%（4 構成）、LLM 要約が 41.5〜55.4%。
  - Qwen3-Coder 480B の解決率は、masking 54.8%、要約 53.8%、何もしない場合 53.4%。
  - 要約を挟むと軌跡が長くなる。Gemini 2.5 Flash で平均 52 ターンとなり、masking の 44 ターンより約 15% 長い。
  - 要約の API 呼び出しは 1 インスタンスのコストの最大 7.2% を占めた。
  - masking を先に使い、後から要約に切り替えるハイブリッドは、masking より 7%、要約より 11% 安かった。
- 限界: 冗長なツール出力が多いソフトウェア工学領域だけで評価している。圧縮の発動条件は固定。Gemini 2.5 Flash（thinking）では、何もしない場合（40.4%）が両手法より良かった。
- 出典: https://arxiv.org/abs/2508.21433

### 2.2 ACON: Optimizing Context Compression for Long-horizon LLM Agents

- 書誌: Minki Kang, Wei-Ning Chen, Dongge Han ほか。2025 年 10 月。arXiv:2510.00615
- 主張: 圧縮の指示文（guideline）を、失敗例との対比で最適化できる。
- 手法:
  - 全文脈なら成功し、圧縮すると失敗する例を集める。最適化役の LLM（o3）が両方を読み、圧縮で何が失われたかを指摘して guideline を直す。
  - 履歴は 4096 トークン、観測は 1024 トークンを超えたときに圧縮する。
- 結果:
  - ピークトークンは 26〜54% 減った。AppWorld の精度は 56.0% から 56.5% で維持した。
  - 小さなモデルに蒸留しても教師の 95% 以上の性能を保った。
- 失われやすい情報: 最適化された guideline と付録の分析からわかる。
  - guideline が残すよう求めるもの: 因果関係、変化していく状態、前提条件、期限などの判断材料。認証トークン、ページング状態、エンドポイント名、ID・パスなど、比較や API 呼び出しに要る識別子。
  - 履歴要約の指示: 「次のセッションで再宣言すべき実行時の値をすべて記録」「繰り返しを防ぐため、エラーや失敗した試みの要点を含める」（Appendix D）。
  - 失敗の分類: 重要事実の欠落、誤った要約、変数・状態の喪失、不要な再発見、API の誤用。
  - 履歴圧縮と観測圧縮を同時に使うと、単独の場合より大きく性能が落ちる。
- 限界: 主に GPT 系で評価している。圧縮によって遅延が増える。情報探索タスクでは、強い圧縮が最終判断に要る細部を落とす。
- 出典: https://arxiv.org/abs/2510.00615

### 2.3 Agentic Context Engineering (ACE): Evolving Contexts for Self-Improving Language Models

- 書誌: Qizheng Zhang, Changran Hu, Shubhangi Upasani ほか。2025 年 10 月（v3 は 2026 年 3 月改訂）。arXiv:2510.04618
- 主張: 文脈（playbook）を全面的に書き直すと、2 つの問題が起きる（§2.2）。
  - brevity bias: 最適化が短く汎用的な指示に流れ、領域固有の細部が落ちる。
  - context collapse: 毎回書き直すたびに短く情報の乏しい要約に縮む。実例では、ステップ 60 で 18,282 トークン（精度 66.7）あった文脈が 122 トークン（精度 57.1）に縮み、適応なしの基準値 63.7 を下回った。
- 手法（§3）:
  - Generator・Reflector・Curator の 3 役に分ける。Curator は小さな差分（delta）だけを書き、LLM 以外の処理でマージする。
  - 各項目（bullet）は、一意の ID と「役に立った／害になった」の回数というメタデータを持つ。
  - grow-and-refine: 新しい項目は追記し、既存の項目はその場で更新する。重複は埋め込みで除く。
- 結果: AppWorld で平均 +10.6%、金融で平均 +8.6%。適応にかかる時間は平均 86.9% 減った。Reflector を外すと平均 59.4 から 55.1 に下がる（Table 3）。
- 限界: 強い Reflector が必要。ラベルや信頼できるフィードバックがないと劣化しうる。短い指示で足りるタスクには向かない。
- 出典: https://arxiv.org/abs/2510.04618

### 2.4 Dynamic Cheatsheet: Test-Time Learning with Adaptive Memory

- 書誌: Mirac Suzgun, Mert Yuksekgonul, Federico Bianchi ほか。2025 年 4 月。arXiv:2504.07952
- 主張: 推論時に戦略やコード片を自分でまとめて再利用すると、同じ失敗を繰り返さなくなる。GPT-4o の Game of 24 は 10% から 99% に上がった（Abstract）。
- 備考: ACE はこの手法を基準手法とし、全面書き換えによる context collapse を指摘している。
- 出典: https://arxiv.org/abs/2504.07952

### 2.5 MemGPT: Towards LLMs as Operating Systems（Letta の前身）

- 書誌: Charles Packer, Sarah Wooders, Kevin Lin ほか。2023 年 10 月。arXiv:2310.08560
- 主張: OS の仮想メモリにならい、文脈内（高速）と外部記憶（低速）の間で LLM 自身がデータを出し入れする。
- 評価: 文脈長を超える文書の分析と、複数セッションの対話で評価している（Abstract）。
- 備考: 2023 年の研究だが、「外部記憶に退避し、必要なときに呼び戻す」という復元可能な設計の原型である。
- 出典: https://arxiv.org/abs/2310.08560

### 2.6 A-MEM と Mem0

- A-MEM: Agentic Memory for LLM Agents
  - 書誌: Wujiang Xu, Zujie Liang, Kai Mei ほか。NeurIPS 2025。arXiv:2502.12110
  - 主張: Zettelkasten にならい、記憶ごとに文脈説明・キーワード・タグという構造化属性を持つノートを作り、関連する記憶へのリンクを張る。新しい記憶が入ると、既存ノートの属性も更新する（Abstract）。
  - 出典: https://arxiv.org/abs/2502.12110
- Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory
  - 書誌: Prateek Chhikara, Dev Khant, Saket Aryan ほか。2025 年 4 月。arXiv:2504.19413
  - 手法（§2.1、Algorithm 1）: 新しい事実ごとに、類似した既存の記憶を 10 件取り出す。LLM が ADD／UPDATE／DELETE／NOOP のどれかを選び、矛盾する古い記憶は DELETE する。抽出時には、会話全体の要約と直近 10 メッセージを併せて渡す。
  - 結果（Table 2）: LOCOMO の総合 J スコアは、全文脈が 72.90% で最も高く、Mem0 は 66.88%。Mem0 は p95 遅延を 17.1 秒から 1.4 秒に、トークンを 90% 以上減らした。
  - 限界: 評価は LOCOMO の 10 会話だけ。LLM 判定による評価。
  - 出典: https://arxiv.org/abs/2504.19413

### 2.7 ReSum: Unlocking Long-Horizon Search Intelligence via Context Summarization

- 書誌: Xixi Wu, Kuan Li, Yida Zhao ほか。2025 年 9 月。arXiv:2509.13313
- 手法:
  - 文脈が上限（32k）に近づくと要約ツールを呼び、要約から探索を再開する。
  - 要約の指示は「会話に明示された情報だけを使い、推測を含めない」で、出力は "Essential Information" 欄（Appendix C）。
  - 情報の欠落や次の行動を書かせる指示は、あえて入れていない。著者は、それを入れると自己検証を繰り返す罠に陥るからだと説明している。
- 結果: 訓練なしで ReAct より平均 4.5% 高く、RL（ReSum-GRPO）を加えるとさらに 8.2% 高い。要約専用に訓練したモデルは、汎用モデルで要約するより良かった（Table 1）。
- 限界: 情報損失そのものは測っていない。「確実な情報だけ」という規則のため、部分的な手がかりや仮説が落ちうる。
- 出典: https://arxiv.org/abs/2509.13313

### 2.8 AgentFold と Context-Folding

- AgentFold: Long-Horizon Web Agents with Proactive Context Management
  - 書誌: Rui Ye, Zhongwang Zhang, Kuan Li ほか。2025 年 10 月。arXiv:2510.24699
  - 手法（§3.2–3.3）: 文脈を「質問、ツール、多段階の状態要約、最新のやり取り」の 4 部で構成する。各ステップで、最新のやり取りだけを細かく畳むか（granular condensation）、複数の要約をまとめて粗く統合するか（deep consolidation）を選ぶ。
  - 結果: 100 ターン後の文脈は約 7k トークンで、ReAct より 92% 小さい（§4.1、Figure 3）。BrowseComp 36.2%（Abstract）。
  - 毎ステップ全履歴を要約し直す方式への批判（§3.5）: 1 回の要約で 1% の確率で重要な細部が落ちると仮定すると、ステップ 1 の発見が 100 ステップ後まで残る確率は約 36.6% になる。これは実測ではなく仮定に基づく試算である。
  - 出典: https://arxiv.org/abs/2510.24699
- Scaling Long-Horizon LLM Agent via Context-Folding
  - 書誌: Weiwei Sun, Miao Lu, Zhan Ling ほか。2025 年 10 月。arXiv:2510.11967
  - 主張: サブタスクを枝として実行し、終わったら途中経過を畳んで結果の要約だけを残す。Deep Research と SWE で ReAct と同等以上の成績を、10 分の 1 の文脈で出した。要約ベースの文脈管理を大きく上回った（Abstract）。
  - 備考: HTML 版がなく、本文の表は確認していない。
  - 出典: https://arxiv.org/abs/2510.11967

### 2.9 MemAgent、MEM1、HiAgent、Sculptor（abstract で確認）

- MemAgent（Hongli Yu ほか、ICLR 2026 Oral、arXiv:2507.02259）: 文章を区切って読み、固定長のメモリを上書きで更新するよう RL で訓練した。8K の文脈で 3.5M トークンの QA に外挿し、損失は 5% 未満。 https://arxiv.org/abs/2507.02259
- MEM1（Zijian Zhou ほか、2025 年 6 月、arXiv:2506.15841）: 毎ターン、記憶と推論を兼ねる内部状態を 1 つだけ更新し、不要な情報を捨てる。メモリ使用量は一定。16 目的のマルチホップ QA で、Qwen2.5-14B と比べて性能 3.5 倍、メモリ 3.7 分の 1。 https://arxiv.org/abs/2506.15841
- HiAgent（Mengkang Hu ほか、2024 年 8 月、arXiv:2408.09559）: 行動の前にサブゴールを立て、終わったサブゴールの行動・観測の組を要約に置き換える。現在のサブゴールに関係する組だけを残す。5 タスクで成功率 2 倍、平均ステップ数 3.8 減。 https://arxiv.org/abs/2408.09559
- Sculptor（Mo Li ほか、2025 年 8 月、arXiv:2508.04664）: 文脈を断片化するツール、要約・隠す・戻す（hide/restore）ツール、精密検索ツールを LLM に与える。先に入った無関係な情報が推論を妨げる proactive interference を減らす。訓練なしでも改善した（Abstract。数値は未確認）。 https://arxiv.org/abs/2508.04664

### 2.10 2026 年の圧縮研究（失われる情報を直接測ったもの）

#### Towards Reliable Context Compression for Long-Horizon Agents: An Empirical Study of Execution Instability

- 書誌: Guanghui Min, Liang Wu, Mayank Darbari ほか。2026 年 8 月、プレプリント。arXiv:2608.06503
- 主張: 圧縮すると、直近のやり取りの影響が弱まる。行動の失敗、同じ探索の繰り返し、実行ごとのばらつきが増える。
- 結果（AppWorld）:
  - 全履歴での行動からのずれは、新しいやり取りを原文で残すと 0.149、要約に圧縮すると 0.233、省くと 0.289（Figure 3）。
  - 圧縮直後の最初の行動では、失敗・エラーとなる行動が 0.108 増えた（Figure 4）。
  - 精度は、圧縮なし 85.7、提案手法 TRACE 77.1、最良の既存プロンプト 71.4（Table 1）。
- 限界: 予備的な研究で、AppWorld だけ、モデル 2 種で評価している。
- 出典: https://arxiv.org/abs/2608.06503

#### Adapting Context Compression for Long-Horizon Agents with Counterfactual Continuations（PAIR）

- 書誌: 同じグループ。2026 年 9 月、プレプリント。arXiv:2609.36526
- 主張: 圧縮は「解けるかどうか」より先に「毎回安定して解けるか」を損なう（§3.1、Figure 1）。大きな劣化は少数の圧縮時点に集中する（197 時点中、継続成功率を 0.5 以上下げたのは 11 時点。§3.2–3.3）。
- 手法: 固定した構造化テンプレートの節構成は変えず、各節の指示文だけを直す。
- PAIR で加わった指示（Appendix D.4、要約）:
  - ユーザーの目標と明示された制約（正確な条件、版、日付、目標件数）を全部残す。
  - 前回の要約と最新の結果を突き合わせ、古い状態を残さない。
  - 回答や状態の裏付けがあるときだけ Done にし、裏付けがなければ「試したが未解決」と書く。
  - ファイルパス、関数名、エラーメッセージ、クエリのパラメータを正確に残す。
- 結果: AppWorld では、圧縮なしの 84.1% と同等以上の 84.7〜85.9% になった（Table 1）。τ²-Bench Retail では、なお差が残る（Table 2b）。
- 限界: 環境の状態を巻き戻せることが前提。取り消せない操作がある環境は対象外。
- 出典: https://arxiv.org/abs/2609.36526

#### Prune the Summary, Not the History: Source-Judged Compaction for Long-Horizon Agents（SJC）

- 書誌: Guanghui Min, Chen Chen。2026 年 10 月、プレプリント。arXiv:2610.20927
- 主張:
  - compaction の指示は「決定」と「次の一手」を書かせる。そのため要約には、環境が確定させた事実と、圧縮器が書いた推論が混ざり、エージェントは後で両者を区別できない。
  - 調べた 29 種の compaction プロンプトのうち 21 種が、決定か次の一手を書かせていた（§3.1、Table 8）。
- 結果:
  - OpenClaw の構造化圧縮器を分析した。節は Decisions、Open TODOs、Constraints/Rules、Pending user asks、Exact identifiers の 5 つ。
  - 失敗 35 件中 29 件（83%）が、要約の特定の記述を実行した行動に遡れた。そのうち 22 件は環境出力に裏付けのない記述だった（§3.2）。
  - 内訳は、制約の意味を変えた言い換え 15 件、頼まれていない成果物の捏造 5 件、環境と矛盾する状態 3 件。
  - 節ごとの裏付けのない割合（Table 2）: Pending user asks 86.1%、Open TODOs 67.7%、Decisions 21.0%、Constraints/Rules 11.1%、Exact identifiers 3.4%。
  - 手法: 各記述が環境出力か前回の要約に出典を持つかを判定し、持たない記述を消す。これで実行間の信頼性が 2.1〜8.9% 上がった（Tables 3–4）。
- 限界:
  - 判定するのは出典の有無で、正しさではない。裏付けのある記述とない記述の正答率は 92.2% と 90.6% でほぼ同じ。
  - 正しい記述も消してしまう。
  - 評価は 2 ベンチマーク、1 種の圧縮器だけ。
- 出典: https://arxiv.org/abs/2610.20927

#### The Sleeping Agent: What Gist-Based Context Compression Loses and Why

- 書誌: Nicholas E. Kyrkewood。2026 年 8 月、プレプリント（単著）。arXiv:2608.11775
- 主張: 要旨（gist）を抽出する要約は、関係や出来事の構造を残すが、日付と時刻を捨てる。
- 結果:
  - 時間表現の保存率は 3.05% だった。指示に「日付・時刻・期間・年齢・時間表現を原文のまま残すこと」という 1 文を追加すると 62.39% に上がった。固有名詞と出来事の保存率はほぼ変わらない（Table 3）。
  - 時間に関する質問の精度は 0.156 から 0.470 に上がった（Table 2）。
  - 多段推論の質問では、要約は切り詰めより大きく良かった（0.407 対 0.157）。
- 限界: LoCoMo だけで評価。全文脈との比較は 2 会話だけ。単著。
- 出典: https://arxiv.org/abs/2608.11775

#### Maximising Transparency in Context Compaction Improves Retention of Facts and Commitments for Lightweight Coding Agents

- 書誌: Felix Woolford。2026 年 10 月、プレプリント（単著）。arXiv:2610.20116
- 手法（§3.1）:
  - 圧縮範囲にあるユーザー発言とアシスタントの地の文は、一字一句残す。ツール出力と推論は消し、ツール呼び出しは 1 行の署名にする。読んだファイルと変更したファイルは「文脈にない」として一覧にする。
  - チェックポイントの見出しに、何を残し何を消したかを書く。残した発言は「言われたことの記録であって、内容が正しいことの確認ではない」と明記する。
  - 再方向づけの指示を置く。必要な文書を読み直す、リポジトリの状態を確かめる、編集前にファイルを読み直す、消えた推論やツール出力に由来する知識は未検証として扱う、の 4 つ。
  - セッションファイルは追記専用で、消した内容は `context_lookup` ツールで検索できる。
- 結果（Qwen3.8-27B、Table 4–5）:
  - commitments（ユーザーが会話中だけで決めたルール）の遵守率は、提案手法 74.1%、モデルが書く要約 64.2%、決定的な抽出（pi-vcc）53.1%。疑いを示さずに間違える「confident failure」は 14.8%、22.2%、40.7%。
  - 埋め込んだ事実の想起率は、提案手法 97.8%、モデル要約 75.3%。
  - モデル要約では、5〜6 回目の圧縮で多くのセッションが破綻した（§4.2）。
  - フロンティアモデル（GPT-6.1 Sol）では差が縮んだ。commitments はモデル要約が 74.1%、提案手法が 69.1% で、有意差はない。
- 限界:
  - 手法の作者自身による評価。
  - プローブではファイルとシェルのツールを外しているが、実際のエージェントはファイルを再読できる。再読は事実の想起を助けるが、commitments は助けない。
  - 約 10 回を超える圧縮は試していない。
- 出典: https://arxiv.org/abs/2610.20116

#### Bud ContextCompact 2.0: Context Compaction for Agent Success and Accuracy with Small Language Models and Constrained Context Windows

- 書誌: Jithin VG, Ditto PS。2026 年 10 月、プレプリント。arXiv:2610.25516
- 結果（Abstract）:
  - SWE-bench Verified の 100 タスク（27B モデル、49K ウィンドウ）で、長いセッションの解決率が 41% から 53% に上がった。
  - 圧縮しない場合の主な失敗は、履歴があふれることではなかった。履歴が残した余白を推論ターンが使い切ることだった。
  - 改善は、余白を残せるほど早く圧縮を発動したときだけ現れた。要約 1 回に中央値 161 秒かかる。
- 出典: https://arxiv.org/abs/2610.25516

#### その他（abstract で確認、本文の数値は未確認）

- REMORY（Hanchen Xia ほか、arXiv:2610.11287）: テキスト要約だけでは後の判断を支えきれないとして、要約の後ろに学習した soft memory token を付け足す。 https://arxiv.org/abs/2610.11287
- ARC（Yilun Yao ほか、arXiv:2601.12030）: 受動的な要約では初期の誤りや的外れな強調が残り続けるとして、振り返りで作業文脈を組み直す。BrowseComp-ZH で最大 11 ポイント改善。 https://arxiv.org/abs/2601.12030
- Escaping the Context Bottleneck（Xiaozhe Li ほか、arXiv:2604.11462）: 軽量なキュレーターが、環境の雑音を削り「推論の錨（reasoning anchors）」を残す。WebArena で 36.4% から 41.2%。 https://arxiv.org/abs/2604.11462

### 2.11 How Memory Management Impacts LLM Agents: An Empirical Study of Experience-Following Behavior

- 書誌: Zidi Xiong, Yuping Lin, Wenya Xie ほか。2025 年 5 月。arXiv:2505.16067
- 主張: エージェントは、似た過去の記録に似た出力を返す（experience-following）。そのため誤った記録は誤りを伝播させる。正しく見える記録でも、役に立たないか誤導することがある（Abstract）。記憶に何を入れるかの品質管理が重要だとする。
- 含意: 記録に誤った「確定事実」を書くと、復帰後の行動がそれに従ってしまう。
- 出典: https://arxiv.org/abs/2505.16067

### 2.12 小括: 要約で失われやすい情報

| 種類 | 報告 | 根拠の強さ |
|---|---|---|
| 日付・時刻・期間 | 要旨要約での保存率 3%。1 文の指示で 62% に回復（Sleeping Agent、Table 3） | 単著、LoCoMo のみ |
| 識別子・変数・トークン・パス・エラーメッセージ | ACON の失敗分類（変数・状態の喪失）と guideline、PAIR の追加指示 | 複数の研究で一致 |
| ユーザーが会話中だけで決めたルール（commitments） | モデル要約は言い換えや狭めをし、confident failure が多い（transparent-compact）。制約の言い換えが失敗の最大要因（SJC、15 件） | 2 つの研究で一致 |
| 失敗した試み・エラー | ACON の guideline に明記。「不要な再発見」が失敗分類にある | 中程度 |
| 直近のやり取りの影響 | 圧縮すると全履歴からのずれが 0.149 から 0.233 に増える（Execution Instability） | 予備的 |
| 未解決事項・次の一手 | 落ちるのではなく捏造されやすい。Pending asks の 86%、Open TODOs の 68% が裏付けなし（SJC） | 1 研究、1 圧縮器 |
| 決定の理由 | ACON は因果関係を残すべきものに挙げ、Anthropic は Claude Code が「アーキテクチャ上の決定」を残すと書く。損失率を直接測った研究は見つからなかった | 未測定 |
| 状態の完了・未完了 | 裏付けなしに Done にする誤りを PAIR が修正。「完了」と主張する失敗が多い（Context Rot in Coding Agents） | 中程度 |

---

## 3. 構造化メモと自由記述の要約、増分更新と全書き換え

### 3.1 構造化メモの有利を示す証拠

- 外部の状態ファイルから文脈を組み直す方式（InfiAgent、arXiv:2601.03204、Chenglin Yu ほか、2026 年 1 月）
  - 手法: 計画、進捗、中間成果物、ツール出力、検証ログを作業ディレクトリのファイルに置き、「進捗の正本」とする。毎ステップ、そのスナップショットと直近 10 行動から文脈を組み直す。
  - 結果（Table 1、80 本の論文レビューのカバー率）: ファイル状態ありでは、GPT-OSS-20B が平均 67.1、Claude-4.5-Sonnet が 80.0。ファイル状態なし（圧縮した文脈）では 3.2 と 27.7。著者は「圧縮だけでは持続的な状態を置き換えられない」と結論している（§5.2）。
  - 限界: 誤った内容がファイルに書かれると、それが下流に伝播する。研究系のタスクでしか評価していない。
  - https://arxiv.org/abs/2601.03204
- 外部チェックリスト（1.11）: 終了前に 24 項目のチェックリストを確かめさせると 10/10、一般的な自己点検では 5/10。著者は、未完了の義務は小さく明示的な台帳として transcript の外に置くべきだとする。
- 節を固定したテンプレート（2.10 の PAIR、TRACE）: どちらもテンプレートの節構成を固定し、節ごとの指示文だけを最適化して改善した。節を固定すると、どの節の指示を直せばよいかを特定できる。
- 構造化属性を持つ記憶（A-MEM、Mem0）: A-MEM は記憶ごとにキーワード・タグ・文脈説明を持つ。Mem0 は記憶ごとに ADD／UPDATE／DELETE を選ぶ。ただし、どちらも自由記述の要約と同条件で比べた研究ではない。

### 3.2 構造化の落とし穴

- 構造化したからといって正しくなるわけではない（SJC）。5 節構造の圧縮器でも、「Pending user asks」「Open TODOs」のように推論を書かせる節では大半が裏付けのない記述だった。節を設けると、書くべき事実がないときにも埋めようとする可能性がある。これは著者の主張ではなく、本資料の推論である。
- transparent-compact は「タスクごとに履歴を構造化しなくても」、地の文を原文のまま残せば、軽量モデルではモデル要約より良いと主張している。一方フロンティアモデルでは、モデル要約が commitments で僅差で上回った（有意差なし）。
- 出力形式の制約は推論を損なうことがある（Let Me Speak Freely?、Zhi Rui Tam ほか、arXiv:2408.02442）。JSON などの形式で答えさせると推論性能が下がり、制約が厳しいほど下がる（Abstract）。これは解答の出力形式についての結果で、記憶ファイルの形式を直接比べたものではない。ただし「理由」など推論を含む欄まで厳格な形式にするのは避けたほうがよい。 https://arxiv.org/abs/2408.02442
- 結論: 「同じ情報量で、構造化した要約と自由記述の要約を比べる」対照実験は見つからなかった。構造化の有利を支える証拠は、すべて間接的なものである。外部ファイル化、節ごとの最適化、チェックリストによる検証が効いている。

### 3.3 増分（delta）更新と全書き換え

- ACE（2.3）: 全面書き換えでは、18,282 トークンが 122 トークンに縮み、精度が適応なしの基準値を下回った。ID 付き項目への delta 更新と、非 LLM 処理によるマージでこれを避け、適応時間も 86.9% 減らした。全書き換えを直接ベースラインに置いた比較としては最も明確な証拠である。
- AgentFold（2.8）: 毎ステップ全履歴を要約し直す方式は、細部が不可逆に失われる危険を累積させる。1%/回 と仮定すると、100 回後に残る確率は 36.6%。仮定に基づく試算である。
- transparent-compact（2.10）: 圧縮を繰り返すと、モデル要約は 5〜6 回目で多くのセッションが破綻した。原文を保つ方式は 8 回の圧縮でも 96.6〜100% の想起を保った。
- Mem0（2.6）: 事実単位で ADD／UPDATE／DELETE／NOOP を選ぶ。矛盾する古い記憶を明示的に DELETE するので、古い記述が distractor として残るのを防げる。
- PAIR（2.10）: 「前回の要約と最新の結果を突き合わせ、古い状態を残さない」という指示で改善した。増分更新でも、古い項目を照合して消す工程が要る。
- ChronoMem（Yongye Su ほか、arXiv:2607.27773、2026 年 7 月）: 記憶を書き込むたびに全体のスナップショットを残し、自然言語の指示で過去の版に戻せるようにした。前に進むだけの記憶は、訂正や汚染に弱いと指摘している（Abstract）。 https://arxiv.org/abs/2607.27773
- Anthropic の実務報告（4.2）: 機能一覧を JSON に置き、エージェントには `passes` 欄だけを変えさせた。理由は、Markdown より JSON のほうが、モデルが不適切に書き換えたり上書きしたりしにくいから。これは観察に基づく記述で、定量評価ではない。

---

## 4. 復元可能な圧縮（restorable compression）

### 4.1 用語の出典（実務報告、査読なし）

- Yichao 'Peak' Ji, "Context Engineering for AI Agents: Lessons from Building Manus"（Manus 技術ブログ、2025-07-18）
  - "Our compression strategies are always designed to be restorable." URL を残せばウェブページの本文を文脈から消してよい。サンドボックスにファイルパスが残っていれば、文書の中身を省いてよい。
  - ファイルシステムを「究極の文脈」として扱い、外部化した記憶にする。
  - todo.md を書き換え続けると、目的が文脈の末尾に置き直され、lost in the middle が減る（"recitation"）。
  - 失敗した行動やエラーは文脈に残す。"Erasing failure removes evidence."
  - KV キャッシュのため、文脈は追記専用にする。
  - https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus

### 4.2 Anthropic の実務報告（査読なし。Claude Code の実装に関する一次情報）

- "Effective context engineering for AI agents"（Prithvi Rajasekaran ほか、2025-09-29）
  - Claude Code の compaction は「アーキテクチャ上の決定、未解決のバグ、実装の詳細」を残し、冗長なツール出力を捨てる。圧縮後は、要約と「直近にアクセスした 5 ファイル」で再開する。
  - compaction を作るときは、まず再現率（必要なものを落とさないこと）を最大化し、次に精度（余計なものを削ること）を上げる。
  - ツール結果の消去を「最も安全で軽い圧縮」と呼んでいる。
  - ファイルパスなどの軽い識別子を持っておき、必要なときに読み込む（just-in-time）。
  - NOTES.md などの構造化ノート。Pokémon の例では、文脈がリセットされた後もノートを読んで続行した。
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- "Effective harnesses for long-running agents"（Justin Young、2025-11-26）
  - 初回のセッションで `init.sh`、`claude-progress.txt`、最初の git commit を作る。2 回目以降の各セッションは、1 機能ずつ進めて記録を残す。
  - セッション開始時の手順は 3 つ。`pwd` で作業ディレクトリを確かめる。「git ログと進捗ファイルを読んで、直近の作業を把握する」。機能一覧から未完了で優先度の高いものを選ぶ。
  - 観察された失敗: 一度に作りすぎて途中で文脈が尽きる。進捗を見て早々に完成と宣言する。十分にテストせず完了にする。
  - "However, compaction isn't sufficient."
  - https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

### 4.3 論文での実装と評価

- Observation masking（2.1）: 古いツール出力をプレースホルダに置き換える。原文は再実行や再読で取り戻せる。この単純な方式が LLM 要約と同等以上の効率だった。
- Memex(RL)（Zhenting Wang ほか、arXiv:2603.04257、2026 年 3 月）
  - 手法: 作業文脈には「構造化された進捗の要約」と「安定した索引（index と説明の組）」だけを置き、原文は外部ストアに索引付きで保存する。`ReadExperience(index)` で正確な原文を取り戻す。
  - 結果: 改造した ALFWorld で、成功率が 24.22% から 85.61% に、ピーク文脈が約 43% 減った（Figure 4）。
  - 限界: 比べているのは RL 訓練の有無だけで、要約のみ・切り詰めとの比較はない。要約を 300 トークンに強制した設定。
  - https://arxiv.org/abs/2603.04257
- LCM: Lossless Context Management（Clint Ehrlich, Theodore Blackman、Voltropy PBC、arXiv:2605.04050）
  - 手法: 全メッセージを不変ストアに原文で保存し、要約はその「派生キャッシュ」とする。要約の DAG は元メッセージへのポインタを持つ。ファイル ID は要約を重ねても引き継がれ、再読できる。`lcm_grep`、`lcm_describe`、`lcm_expand` で戻せる。
  - 結果: OOLONG で Opus 4.6 を使い、平均 74.8 で Claude Code の 70.3 を上回った（Figures 1, 6）。8K と 16K では Claude Code が僅かに上だった。
  - 限界: データ汚染の懸念。開発元による評価。
  - https://arxiv.org/abs/2605.04050
- ACM: Agentic Context Management for Long Horizon Tasks（Xiaochuan Li ほか、arXiv:2607.23809）: 捨てた内容を外部記憶に退避し、必要に応じて問い合わせる文脈編集ツールを与え、事後学習した（Abstract）。 https://arxiv.org/abs/2607.23809
- Sculptor（2.9）の hide/restore ツール、transparent-compact（2.10）の `context_lookup` と「文脈にないファイル」一覧も同じ考え方に立つ。
- 毎ステップ作業ディレクトリから組み直す InfiAgent（3.1）は、復元可能な圧縮を極端に進めた形である。
- Measure Before You Manage（Le Chen ほか、arXiv:2608.31057）: コーディングエージェントの作業文脈では、ツール出力が全体量の 55.5%、ファイル内容などの成果物が 28.3% を占めた。成果物は滞留が長い（平均 10.71 ステップ、Figure 1、§3）。どちらも再読や再実行で取り戻せる種類の情報で、捨てる候補になる。ただし、どれを捨てても安全かは保存状態の指標だけでは決まらないと著者は書いている。 https://arxiv.org/abs/2608.31057

### 4.4 根拠の強さ

- 原文を残し、索引やパスから戻せる設計は、Memex、LCM、ACM、transparent-compact で改善を示している。ただし「同じ予算で要約だけの場合」と厳密に比べたものは少ない。Memex には比較がない。transparent-compact はファイル再読を外した条件で測っている。
- 一方、ファイルや git ログのように原文が環境にもともと残っている情報は、記録に複写する必要がない。パスやコミット範囲を書いておけばよい。Complexity Trap の結果（再取得できる観測は捨ててよい）と、Measure Before You Manage の量的分析がこれを支える。

---

## 5. /refresh 設計への含意

### 5.1 必ず残すもの（失われやすいと実測された順）

1. ユーザーの目標と、会話中だけで決まったルール（commitments）。要約で言い換えると意味が変わる（SJC で 15 件、transparent-compact）。ユーザー発言を原文のまま引用し、どのターンで言われたかを添える。
2. 識別子。ファイルパス、関数名、ブランチ、コミットハッシュ、PR・issue 番号、環境名、URL、正確なエラーメッセージ（ACON、PAIR）。言い換えずにコードスパンで書く。
3. 日付・時刻は絶対表記で書く。「昨日」「さっき」は使わない（Sleeping Agent）。
4. 試して失敗したこと。何をしたか、エラー原文、なぜ駄目だったか（ACON、Manus "keep the wrong stuff in"）。同じ試みを繰り返さないためで、「不要な再発見」を防ぐ。
5. 決定とその理由。理由の損失を直接測った研究はないが、ACON は因果関係を、Anthropic はアーキテクチャ上の決定を残すべきものに挙げている。理由は自由記述で書いてよい。形式で縛ると推論が損なわれる懸念がある（Let Me Speak Freely?）。
6. 未完了の義務の台帳（チェックリスト）。完了条件と確認方法を書く（Context Rot in Coding Agents、Anthropic の「早すぎる完成宣言」）。

### 5.2 各記述に出典と確度を付ける

- 記録の各項目を「観測した事実」と「自分の推論・計画」に分け、ラベルを付ける。SJC では、推論を書かせる欄（Pending asks、Open TODOs）の 68〜86% に裏付けがなく、失敗の 83% が要約の記述の実行に遡れた。
- 観測した事実には出典を付ける。例: `path:line`、実行したコマンドとその出力の要点、コミットハッシュ、ユーザー発言の引用。
- 未解決事項・TODO には出所を付ける。「ユーザーが依頼した」のか「自分が必要と判断した」のかを区別する。
- Done は裏付けがあるときだけ付ける。裏付けがなければ「試したが未検証」と書く（PAIR）。
- 記録自体も、復帰後は「未検証の手がかり」として扱う（transparent-compact の見出し文、Xiong らの誤り伝播）。

### 5.3 書く順序

- 先頭に、目標と制約（ユーザー原文の引用）を置く。
- 中央に、事実、決定、失敗した試み、識別子、復元ポインタなど量の多い参照用の情報を置く。中央は読み落とされやすいので、見出しを後で問われる語と同じ語にして拾いやすくする（NoLiMa）。
- 末尾に、現在地、次の一手、未完了チェックリストを置き、目標を 1 行で再掲する。根拠は、先頭と末尾は保たれやすく、課題の写しを末尾に置くと中央配置の損失が消えること（Lost in the Middle §4.2、Positional Failures）。Manus の recitation も同じ考え方である。
- 推奨する節の順序は次のとおり。
  1. 目標（原文引用）
  2. 制約・ユーザールール（原文引用、ターン番号）
  3. 確定事実（出典付き）
  4. 決定と理由
  5. 試して失敗したこと
  6. 識別子
  7. 復元ポインタ（再読すべきファイル、git ログの範囲、再実行するコマンド）
  8. 未完了チェックリスト（出所・完了条件付き）
  9. 次の一手と目標の再掲

### 5.4 更新の仕方

- 全文を書き直さず、項目単位の差分で更新する。各項目に安定した ID（例: `D-03`、`F-12`）を振り、追加・更新・削除を項目単位で行う（ACE の context collapse、AgentFold の試算、transparent-compact の多回圧縮）。
- 更新のたびに、既存の項目と最新の結果を突き合わせる。矛盾した項目や古くなった項目は明示的に削除するか「撤回」と書き添える（Mem0 の DELETE、PAIR の「古い状態を残さない」）。古い記述を残すと distractor になる（NoLiMa、Chroma）。
- 制約・ルールの欄は、ユーザーが変えたときだけ更新する。要約役の言い換えで変えてはならない（SJC の「制約の言い換え」）。
- 記録ファイルの履歴を残す。git 管理下に置くか、更新前の版を保存して戻せるようにする（ChronoMem）。
- 書き換えられたくない状態（チェックリストの完了フラグ）は、変えてよい欄を限定した形式にする。Anthropic は JSON の `passes` 欄だけを変えさせた。ただしこれは観察による報告で、定量評価ではない。

### 5.5 書かないもの（復元可能にする）

- ファイルの中身、長いツール出力、ログ全文は複写しない。パス、行範囲、コマンド、コミット範囲だけを書く（Manus、Anthropic just-in-time、Complexity Trap、Measure Before You Manage）。記録が長いほど、それ自体が劣化要因になる（Context Length Alone Hurts、Chroma の focused と full の差）。
- 再取得できない情報だけは原文で残す。会話中だけにあるユーザーの判断・ルール、一度きりの実行結果、外部サービスから取得して再取得が高くつく値。

### 5.6 圧縮後の復帰手順

1. 記録ファイルを読む。
2. 記録の復元ポインタに従い、`git log`、`git status`、`git diff`、関係するファイルを読み直して現状と照合する（Anthropic の harness、transparent-compact の再方向づけ）。記録と現状が食い違ったら、現状を正とし、記録を delta で直す。
3. 記録にある推論ラベル付きの項目（計画・TODO）は、実行前に根拠を確かめる（SJC）。
4. 未完了チェックリストを読み、完了を宣言する前に全項目を確かめる（Context Rot in Coding Agents）。

### 5.7 いつ書くか

- 文脈が満杯になる直前ではなく、余白が残っているうちに書く。Bud ContextCompact では、早めに発動したときだけ改善が出た。Bud では、余白を推論ターンが使い切ることが主な失敗だった。
- 劣化は少数の圧縮時点に集中する（PAIR）。サブタスクの区切り（AgentFold、Context-Folding、HiAgent のサブゴール単位）で記録を更新すると、作業途中の状態を要約するより崩れにくいと考えられる。これは本資料の推論で、直接の比較はない。

### 5.8 /refresh の評価方法（研究の評価設計から）

- commitments プローブ: 会話中だけで決めたルールを破るような次の指示を与え、守れるかを見る（transparent-compact）。
- 埋め込み事実の想起: 識別子・日付・エラー原文を記録の前後で問う（transparent-compact、Sleeping Agent）。
- 平均精度だけでなく、実行間の安定性（Pass^k、すべての試行で成功する率）も見る。圧縮は先に安定性を損なう（PAIR、Laban らの unreliability）。
- 圧縮直後の数手で、失敗行動や繰り返し探索が増えていないかを見る（Execution Instability）。

---

## 付録: 確認した論文一覧（arXiv API で書誌を確認）

| arXiv ID | 題名 | 第一著者 | 年 | 査読状況（arXiv 記載） |
|---|---|---|---|---|
| 2307.03172 | Lost in the Middle | Liu | 2023 | TACL |
| 2406.16008 | Found in the Middle | Hsieh, C.-Y. | 2024 | ACL Findings 2024 |
| 2404.06654 | RULER | Hsieh, C.-P. | 2024 | COLM 2024 |
| 2402.14848 | Same Task, More Tokens | Levy | 2024 | ACL 2024 |
| 2502.05167 | NoLiMa | Modarressi | 2025 | 記載なし |
| 2510.05381 | Context Length Alone Hurts LLM Performance Despite Perfect Retrieval | Du | 2025 | 記載なし |
| 2410.10813 | LongMemEval | Wu | 2024 | ICLR 2025 |
| 2505.06120 | LLMs Get Lost In Multi-Turn Conversation | Laban | 2025 | 記載なし |
| 2605.23170 | Positional Failures in Long-Context LLMs | Zhang | 2026 | 記載なし |
| 2607.17937 | When and How Context Rot Appears in Coding Agents | Xue | 2026 | 記載なし |
| 2609.01660 | How Fast Do Agents Rot? | Mittal | 2026 | 記載なし |
| 2606.29718 | Diagnosing and Mitigating Context Rot in Long-horizon Search | Xia | 2026 | 記載なし |
| 2508.21433 | The Complexity Trap | Lindenbauer | 2025 | ワークショップ（DL4C） |
| 2510.00615 | ACON | Kang | 2025 | 記載なし |
| 2510.04618 | Agentic Context Engineering (ACE) | Zhang | 2025 | 記載なし |
| 2504.07952 | Dynamic Cheatsheet | Suzgun | 2025 | 記載なし |
| 2310.08560 | MemGPT | Packer | 2023 | 記載なし |
| 2502.12110 | A-MEM | Xu | 2025 | NeurIPS 2025 |
| 2504.19413 | Mem0 | Chhikara | 2025 | 記載なし |
| 2509.13313 | ReSum | Wu | 2025 | 記載なし |
| 2510.24699 | AgentFold | Ye | 2025 | 記載なし |
| 2510.11967 | Context-Folding | Sun | 2025 | 記載なし |
| 2507.02259 | MemAgent | Yu | 2025 | ICLR 2026 |
| 2506.15841 | MEM1 | Zhou | 2025 | 記載なし |
| 2408.09559 | HiAgent | Hu | 2024 | 記載なし |
| 2508.04664 | Sculptor | Li | 2025 | 記載なし |
| 2505.16067 | How Memory Management Impacts LLM Agents | Xiong | 2025 | 記載なし |
| 2408.02442 | Let Me Speak Freely? | Tam | 2024 | 記載なし |
| 2608.06503 | Towards Reliable Context Compression (TRACE) | Min | 2026 | 記載なし |
| 2609.36526 | Adapting Context Compression … Counterfactual Continuations (PAIR) | Min | 2026 | 記載なし |
| 2610.20927 | Prune the Summary, Not the History (SJC) | Min | 2026 | 記載なし |
| 2608.11775 | The Sleeping Agent | Kyrkewood | 2026 | 記載なし |
| 2610.20116 | Maximising Transparency in Context Compaction | Woolford | 2026 | 記載なし |
| 2610.25516 | Bud ContextCompact 2.0 | VG | 2026 | 記載なし |
| 2610.11287 | REMORY | Xia | 2026 | 記載なし |
| 2601.12030 | ARC | Yao | 2026 | 記載なし |
| 2604.11462 | Escaping the Context Bottleneck | Li | 2026 | 記載なし |
| 2601.03204 | InfiAgent | Yu | 2026 | 記載なし |
| 2607.27773 | ChronoMem | Su | 2026 | 記載なし |
| 2603.04257 | Memex(RL) | Wang | 2026 | 記載なし |
| 2605.04050 | LCM: Lossless Context Management | Ehrlich | 2026 | 記載なし |
| 2607.23809 | ACM: Agentic Context Management | Li | 2026 | 記載なし |
| 2608.31057 | Measure Before You Manage | Chen | 2026 | 記載なし |

論文以外の一次資料: Chroma 技術報告（2025-07-14）、Anthropic Engineering の 2 記事（2025-09-29、2025-11-26）、Manus ブログ（2025-07-18）。
