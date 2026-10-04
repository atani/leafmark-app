# Leafmark マーケティング計画

> US/Canada向けの投稿画像・英語コピー・計測URLは [marketing/social/posts-en.md](marketing/social/posts-en.md) を参照。

最終更新: 2026-10-02。

## 定期改善の運用（2026-10-02）

毎週月曜10時（日本時間）に、完了週の売上確認、前回施策の評価、小さな改善1件の実施と検証を進めます。主担当は施策判断とチェックを行い、コード修正は `gpt-6-luna` に任せます。

初回確認では、9月21〜27日のDL（販売レポートの `1F`）は8件、Pro購入は0件でした。前週は13件と1件でした。件数が少ないため、売上低下の原因や購入転換率の悪化は断定しません。詳細と出典は `post-launch-kpi.md` に記録しています。

次の優先課題は、購入導線の改善後の獲得状況を確認し、ストア先頭素材の訴求を検証することです。無料書き出しと購入導線は9月10日に検証済みです。新しいコード変更の前に、現在の配信版・ストア素材・完了した28日間の獲得指標を確認します。ストア先頭素材がMarkdownの持ち出し価値を伝えていなければ、先頭1枚の変更案を準備します。

実験は反映日から28日後に評価します。反映前後の同じ期間・同じ地域で表示、商品ページ閲覧、初回DL、購入、通貨別の手取りを比較します。欠測と実際のゼロを区別し、十分な件数がなければ仮説として残します。コード変更・価格変更・複数素材の変更を同時に行わず、審査提出や外部投稿は当該操作の承認に従います。

過去の4週間計画は履歴です。実施済みの施策を再実装せず、現在の一次情報から優先度を更新します。

## 目的

広告費を使わず、購入意向の高い読者へLeafmarkを届ける。最初の4週間は認知の総量よりも、どの流入元がダウンロードと購入につながるかを把握する。

4週間の目安は次のとおり。

- First Time Downloads: 200
- 実利用者からの評価: 10件
- 既存レビューと獲得・購入指標を基に、改善仮説を記録します。
- ダウンロードから購入への転換率: 3〜8%
- 流入元を識別できるダウンロード: 全体の70%以上

数値は保証値ではない。公開直後の基準を作るための目安として使う。

## ポジショニング

中心メッセージは次のとおり。

> Your highlights are yours.
> Buy once. Export to Markdown. No account or tracking.

「高機能なEPUBリーダー」では範囲が広すぎる。ストア、Webサイト、投稿では、次の順で伝える。

1. ハイライトとノートをMarkdownへ持ち出せる
2. 買い切りであり、サブスクリプションではない
3. アカウント、広告、行動追跡がない
4. EPUBの読み心地を細かく調整できる

## 公開ページの現状

2026年7月4日に米国向けApp Storeページを確認した。

- タイトル: Leafmark: EPUB Reader & Notes
- サブタイトル: Highlight, export & read EPUBs
- 価格: 無料、Leafmark Proは$9.99
- 言語: 英語のみ
- 評価: 表示できる件数に達していない
- iPhoneスクリーンショット: 7枚
- 1枚目: ライブラリ画面。「Your library, your way」
- 4枚目: ハイライト一覧。「Highlight and export」
- 6枚目: 統計のロック画面。「Your highlights are yours」

1枚目は製品の独自価値を伝えていない。検索結果や商品ページで最初に見せる3枚を、購入理由に合わせて並べ直す。

## 英語 ASO 改訂案(2026-09-01)

広告費は使わず、Apple Ads Advanced を米国ストアの検索需要を見るためだけに使った。
候補キーワードは追加画面へ一時入力し、保存していない。キャンペーンの作成も行っていない。

| 項目 | 現在 | 次回案 |
|---|---|---|
| App 名 | `Leafmark: EPUB Reader & Notes` | 維持 |
| サブタイトル | `Highlight, export & read EPUBs` | `Export Highlights to Markdown` |
| en-US キーワード | 他社アプリ名と重複語を含む | 一般語のみで100 bytes |

次回の en-US キーワード欄は次のとおり。

```text
ebook,annotation,offline,drm free,private,library,sync,cloud,vertical,stats,bookmark,buy once,search
```

タイトルに検索人気度 3 / 5 の `epub reader` を残し、サブタイトルで検索結果の転換理由を
伝える。Apple Ads で人気度 4 / 5 だった他社アプリ名は、Apple のメタデータルールに
合わせてキーワード欄に入れない。

反映前に App Store Connect Analytics で直前 28 日間を保存し、反映後の同じ 28 日間と
比較する。購入数は累計 3 件と少ないため、先行指標を次の順で見る。

1. App Store Search の Unique Impressions
2. Product Page Views
3. First Time Downloads
4. 検索表示から初回ダウンロードまでの転換率
5. In-App Purchases

検索表示とダウンロードが増えなければメタデータを再検討する。ダウンロードだけが増えて
購入が増えなければ、ASO ではなく無料体験から Paywall までの導線を検討する。

## App Store素材

推奨する先頭3枚は次のとおり。

1. **Own your reading notes**
   Highlights and notes export to clean Markdown.
2. **Buy once. Read for years.**
   One purchase. No subscription or account.
3. **Private by design**
   Your books and notes stay on your device.

続く4枚で、読み心地、2カラム、全文検索、読書統計、ライブラリを見せる。

画面の順番だけでなく、キャプションの役割を分ける。同じ機能名を繰り返さず、「何ができるか」「なぜ安心か」「なぜ支払うか」を1枚ずつ担当させる。

リポジトリ内の `docs/screenshots/6.9-inch/07-paywall.png` には旧名の Pro 表記が残っている。公開中の7枚にはこの画像を使っていないが、今後の素材作成で再利用しない。

## ストア説明文

説明文の冒頭3行は次の内容へ寄せる。

> Keep your EPUB highlights in plain Markdown, not inside another account.
> Leafmark is a private, buy-once reader for iPhone and iPad.
> Read for free. Unlock unlimited annotation and export with one purchase.

機能一覧の前に、対象ユーザーと違いを伝える。PDF非対応やDRM非対応は説明文の末尾に残し、期待値を合わせる。

## 流入チャネル

優先順位は次のとおり。

### 1. App Store検索

- EPUB reader
- EPUB notes
- export highlights
- Markdown reader
- Obsidian highlights
- private ebook reader
- Marvin alternative

検索語は国ごとの表示回数とダウンロードを確認し、タイトル、サブタイトル、キーワードの重複を避ける。Product Page Optimizationは流入が増えてから使う。現在の21ダウンロードでは試験結果が安定しないため、まず先頭3枚を一度だけ変更して前後を比較する。

### 2. MobileRead

既存のベータ案内文を公開報告へ更新します。Marvinを失って自分で作った経緯と、現在の機能・制約を伝えます。

投稿ごとに専用のApp Storeキャンペーンリンクを使う。返信で出た要望は、機能名だけでなく「その機能がないと移行できない理由」まで記録する。

### 3. ObsidianとPKMの利用者

機能紹介より、EPUBからMarkdownへ移す実際の手順を見せる。

- 30秒の画面録画: ハイライト、ノート、Markdown書き出し、Obsidianで開く
- 記事: How I keep EPUB highlights in plain Markdown
- サンプル: Leafmarkが生成するMarkdownの実例

コミュニティの宣伝規則を確認し、許可された場所だけへ投稿する。

### 4. Reddit

候補はr/ebooks、r/ereader、r/ipad、r/ObsidianMD、r/iosapps。各コミュニティで同じ文章を使い回さない。

- 読書系: Apple Booksなどから注釈を持ち出せない問題
- iPad系: 2カラムと外観調整
- Obsidian系: Markdownの出力例
- iOSアプリ系: 買い切りとプライバシー

販売リンクだけの投稿は避け、問題、作った理由、現在の制約、試してほしい点を含める。

### 5. 検索用Webページ

既存サイトに次の3ページを追加する。

- `/epub-highlights-to-obsidian`
- `/private-epub-reader`
- `/marvin-alternative-ios`

各ページは1つの検索意図だけを扱い、App Storeへのキャンペーンリンクを分ける。比較対象の価格や機能は公開情報を確認し、更新日を載せる。

### 6. Xと開発ログ

完成報告だけでなく、利用場面を短く見せる。

- なぜハイライトをMarkdownへ出したいのか
- 買い切りにした理由
- 21ダウンロードから始める記録
- 利用者の要望で何を変えたか

投稿にはブログURLではなく、App Store URLまたはリポジトリURLを目的に応じて使う。技術名を並べず、読書中に困った場面を中心にする。

### 後回しにするチャネル

Product HuntとShow HNは、評価10件、購入者の声3件、30秒のデモがそろってから使う。公開済みでも、改善版の発表として扱える。準備前に一度きりの露出を消費しない。

## 4週間の実行計画

### 第1週: 計測とストア改善

- App Store Connectで獲得、購入、手取りの基準値を保存する
  - 対象: Unique Impressions、Product Page Views、First Time Downloads、Paying Users、Proceeds
- MobileRead、Reddit、Webサイト、X用のキャンペーンリンクを作る
- スクリーンショットの先頭3枚を作り直す
- 説明文の冒頭を「Markdown、買い切り、プライバシー」の順へ変える
- 既存レビューから、利用を妨げる不具合や要望を確認します。

完了条件: すべての投稿先に別の計測リンクがあり、変更前の数値が残っている。

### 第2週: 価値体験の改善

- 無料3件のハイライトをMarkdownへ1回書き出せるようにする
- 書き出し後に内容を確認できる導線を整える
- 4件目のハイライトと2回目の書き出しで文脈に合うペイウォールを出す
- 端末内だけに保存する簡単な診断項目を検討する
- 実機で購入、復元、無料境界を確認する

完了条件: 無料ユーザーがLeafmark独自の成果物を購入前に確認できる。

### 第3週: 対象を絞った公開

- MobileReadへ公開報告を投稿する
- EPUBからObsidianへの30秒動画を公開する
- Redditへ対象別に2件投稿する
- 検索用Webページを1ページ公開する
- すべての反応と要望を1か所へ記録する

完了条件: 流入元ごとのProduct Page Views、ダウンロード、購入を比較できる。

### 第4週: 判断と集中

- 流入元別にダウンロード、購入、セッション、D7リテンションを比較する
- 反応が良い上位2チャネルだけを翌月も続ける
- 獲得・購入指標と既存レビューから、購入を妨げる要因の仮説を記録します。
- iCloud同期、Calibre/OPDS、コレクションのどれを先に作るか、要望数と購入意向で決める
- 100ダウンロード未満なら機能を増やすより配布を続ける

完了条件: 翌月に続けるチャネルと改善1件を、数値と既存レビューを基に判断します。

## コンテンツ案

### 30秒動画

1. EPUB本文を選択する
2. ハイライトとノートを追加する
3. Highlights画面を開く
4. Markdownへ書き出す
5. Obsidianでファイルを開く

最後に「Buy once. No account. No tracking.」だけを表示する。

### 記事

- How I keep EPUB highlights in plain Markdown
- I missed Marvin, so I built the reader I wanted
- What a private EPUB reader does not collect
- Leafmark vs Apple Books for DRM-free EPUB notes

比較記事では、相手製品の強みも書く。確認できない機能や価格は書かない。

## 計測方法

第三者の分析SDKは使わない。[App Store Connect Analytics](https://developer.apple.com/help/app-store-connect-analytics/)と専用キャンペーンリンクを使う。

週次表には次の列を持たせる。

| 週 | 流入元 | 表示 | 商品ページ | DL | 購入 | 手取り | D7 | 主な反応 |
|---|---|---:|---:|---:|---:|---:|---:|---|

見る順番は次のとおり。

1. 表示から商品ページへ進まない: タイトル、サブタイトル、アイコンを見直す
2. 商品ページからDLされない: 先頭3枚、説明文、対象ユーザーを見直す
3. DL後に購入されない: サンプル、書き出し体験、ペイウォールを見直す
4. 購入後に使われない: 読み心地、安定性、欠けている移行機能を見直す

Appleの利用状況とリテンションは、共有に同意したユーザーだけが対象になる。
件数が少ない間は数値が表示されない可能性があります。既存レビューも参照し、原因を推定できない場合は未検証の仮説として記録します。

## US Search Ads テスト（2026-09-06〜09-16）

目的はインストール件数。人気度の高い `epub reader` だけで入札を競るのではなく、
人気度 1〜2 のロングテール語を Exact で並べ、安い tap を数で拾う。
Apple Ads は推奨入札額を個別キーワードに表示しなくなったため、人気度（5 段階）を
キーワード追加パネルの「Related Keyword」検索で読み取り、競合アプリ名を除いて選んだ。

| 項目 | 値 |
|---|---|
| キャンペーン | `Leafmark US Search`（Search Results / United States）。キャンペーン ID 2144620153、広告グループ ID 2150875044 |
| 作成 | 2026-09-06 12:39 JST。作成直後の状態は「App pending review」（Apple Ads 側の審査待ち） |
| 予算 | ¥750/日、終了日 2026-09-16 UTC。合計上限 ¥7,500（$50） |
| 入札 | Manage Bids、広告グループ `epub-en-exact` の Default Max CPT Bid **¥150**（全キーワード同額） |
| キーワード | 14 語すべて Exact。Search Match オフ。内訳は下の表 |
| Apple の推奨 Default Max CPT Bid | **¥597**（作成画面の Suggested 表示、2026-09-06） |

| 人気度 | キーワード |
|---:|---|
| 3 | `epub reader` `ebook` |
| 2 | `book reader` `ebooks reader free` |
| 1 | `epub` `ebook reader` `epub reader free` `e book reader` `ereader` `e reader` `free book reader` `book reader free` `ebooks` `e books` |

損益分岐の CPT は ¥75（$8.5 × US のインストール→購入 11.8% ≒ $1.00 ÷ tap→install 0.5。
[post-launch-kpi.md](post-launch-kpi.md) の取り直しベースライン）。¥150 はその 2 倍で、
直接の回収より件数と評価件数を優先した判断。Apple の推奨 ¥597 は `epub reader` 級の
競合を想定した値で、ロングテール語の実勢はこれより低いと見ている。

判定は次のとおり。

- 語ごとの Impressions / Taps / Avg CPT を見て、tap が付く語だけ残す
- 全体の CPI が $2 を超えたら止める。$1 未満なら継続と予算増を検討する
- 計測は `asc-sales --daily` の US 初回 DL と購入、Lookup API の US 評価件数

## 今月はやらないこと

- 有料広告（例外: 2026-09-06 に始めた US 限定 $50 上限の Search Ads テスト。下の節を参照）
- 有料インフルエンサー施策
- PDF、TTS、同期の同時開発
- 根拠のない多言語展開
- 21ダウンロードだけを基にした価格変更
- 高評価を条件にしたレビュー依頼

日本と韓国から流入しているため、100ダウンロード時点で地域比率を再確認する。比率が続く場合は、アプリ本体より先に日本語と韓国語のApp Storeメタデータを試す。
