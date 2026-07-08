# Leafmark マーケティング計画

最終更新: 2026-07-04。

## 目的

広告費を使わず、購入意向の高い読者へLeafmarkを届ける。最初の4週間は認知の総量よりも、どの流入元がダウンロードと購入につながるかを把握する。

4週間の目安は次のとおり。

- First Time Downloads: 200
- 実利用者からの評価: 10件
- ユーザーとの会話: 5件
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

既存のベータ募集文を、公開報告と利用者募集へ更新する。宣伝文ではなく、Marvinを失って自分で作った経緯、未実装の項目、意見を求めたい点を書く。

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
- 現在の利用者へ、評価ではなく困った点を聞く

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
- 購入を妨げた理由を5件以上集める
- iCloud同期、Calibre/OPDS、コレクションのどれを先に作るか、要望数と購入意向で決める
- 100ダウンロード未満なら機能を増やすより配布を続ける

完了条件: 翌月に続けるチャネル2つと、作る機能1つが数値と利用者の発言で決まっている。

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
件数が少ない間は数値が表示されない可能性もある。利用者との会話を併用する。

## 今月はやらないこと

- 有料広告
- 有料インフルエンサー施策
- PDF、TTS、同期の同時開発
- 根拠のない多言語展開
- 21ダウンロードだけを基にした価格変更
- 高評価を条件にしたレビュー依頼

日本と韓国から流入しているため、100ダウンロード時点で地域比率を再確認する。比率が続く場合は、アプリ本体より先に日本語と韓国語のApp Storeメタデータを試す。
