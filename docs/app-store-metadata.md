# App Store メタデータ草案(英語)

App Store Connect 申請用のテキスト草案。承認が下りたら App Store Connect に転記する。
訴求軸は買い切り・ロックインなし・エクスポート自由(customer-pains.md P2 × P8)。
無料/有料の境界線は [ADR-0005](adr/0005-buy-once-pricing-storekit.md) に従う。

> 注: go-to-market.md §2 は旧案で「無料は蔵書 3 冊まで」と書いてあるが、ADR-0005 が
> 「読書体験は永久無料・課金境界は注釈ワークフロー(ハイライト 3 件 / エクスポート / 統計)」に
> 上書き済み。実装も ADR-0005 準拠。本メタデータは ADR-0005 に合わせる。go-to-market.md §2 は別途更新する。

## App 名(最大 30 字)

```
Leafmark — EPUB Reader
```

App Store 上の表示名(22 字。App Store Connect で受理済み)。ホーム画面の
`CFBundleDisplayName` は短く `Leafmark`。両者は意図的に別(App Store 名は ASO 用に
descriptor を付与、アイコン下は短いブランド名)。

## サブタイトル(最大 30 字)

```
Your highlights are yours
```

25 字。P2 × P8 の訴求コピーをそのまま使う。

## プロモーションテキスト(最大 170 字)

```
A buy-once EPUB reader for readers who annotate. Unlimited highlights, Markdown export to Obsidian or Notion, and reading stats. No subscription. No lock-in.
```

## 説明文(最大 4000 字)

```
Leafmark is a calm, fast EPUB reader for people who read closely and take their notes with them.

Buy it once. No subscription, no account, no cloud lock-in. Your library is plain EPUB files on your device, and your highlights are yours to export any time.

READ THE WAY YOU LIKE
• Reflowable EPUB rendering with light, sepia and dark themes
• Vertical Japanese text (tategaki) renders as the book declares it
• Adjustable font, size, line height and margins
• One or two columns, plus a scrolling mode — great on iPad in landscape
• Full-text search, table of contents and a built-in dictionary lookup
• Your reading position is remembered per book

ANNOTATE AND KEEP YOUR NOTES
• Highlight in four colors and attach notes
• Export every highlight and note to Markdown — drop them straight into Obsidian, Notion or any plain-text vault
• Reading statistics: time today, this week and all time, your streak, and time per book

PRIVACY BY DESIGN
• No account and no sign-in
• No tracking and no analytics
• Everything stays on your device

LEAFMARK PRO
Reading is always free. Import your library, render any book and try the feel before you decide. You also get one free Markdown export, so you can see exactly what lands in your notes before paying. A single one-time purchase, Leafmark Pro, unlocks the full annotation workflow: unlimited highlights (the free tier keeps up to three per book), unlimited Markdown export, and reading statistics. Restore your purchase any time.

GOOD TO KNOW
• Import EPUBs straight from Files — iCloud Drive, Google Drive, Dropbox, or right off your device.
• Works with DRM-free EPUB files. DRM-protected books and PDF are not supported.
• Public-domain EPUBs are available from Public Domain Library and Standard Ebooks.
```

## キーワード(最大 100 字・カンマ区切り・スペース無し)

### en-US(99 字 / 14 語)

```
markdown,obsidian,annotate,notes,export,ebook,calibre,vault,offline,drmfree,notion,logseq,anki,sync
```

### ja(93 字 / 20 語)

```
電子書籍,ハイライト,注釈,読書,読書メモ,読書記録,マークダウン,オブシディアン,書き出し,蔵書,統計,買い切り,サブスクなし,広告なし,縦書き,青空文庫,全文検索,しおり,目次,同期
```

### 改訂の根拠(2026-07-25 実測)

iTunes Search API で対象検索語の上位を実測した結果は次のとおり。

| ストア | 検索語 | Leafmark の順位 |
|---|---|---|
| US | epub reader | 圏外(上位は評価 1 万件級) |
| US | epub highlights export | 圏外 |
| US | annotate ebook | 圏外 |
| JP | epub リーダー | 圏外 |
| JP | 電子書籍 ハイライト | 圏外 |
| JP | epub 注釈 | **3 位** |

評価 1 件の新規アプリが `epub reader` のような head term で評価数千件の既存アプリに勝つ見込みは無い。
獲得可能性のある long-tail(ツール名・買い切り・DRM フリー)へ寄せる。

改訂点は次の 3 つ。

1. **ja の枠を 43 字から 93 字へ**。従来は 57 字が未使用で、さらに `リーダー` `ノート` が
   アプリ名と重複していた。Apple はアプリ名 + サブタイトル + キーワードを自動結合するため重複は純粋な無駄
2. **勝てない広域語を外す**(`book` `library` `reading` `ipad` `sepia`)。`sepia` は検索意図が存在しない
3. **同じ読者層が使うツール名を追加**(`logseq` `anki`)。`obsidian` `notion` と同じ PKM 層を狙う

### 縦書きの検証結果(2026-07-25)

`縦書き` `青空文庫` は当初、対応コードが見当たらなかったため保留にしていた。
実機検証したところ **縦組みは正しく描画される**ことを確認したので採用する。

検証方法は次のとおり。

1. `writing-mode: vertical-rl` と `page-progression-direction="rtl"` を指定した
   最小の EPUB 3 を生成する(日本語の縦組み書籍および青空文庫の EPUB 変換と同じ宣言)
2. 初期化済みシミュレータ(iPhone 17 / iOS 26.5)の `Documents/` へ配置して取り込ませる
3. 描画を確認する

結果は、本文が画面右上から始まり、行が右から左へ進む正しい縦組みだった。
Readium の WKWebView が `writing-mode` をそのまま解釈するため、
アプリ側に専用コードが無くても動作する。

日本語圏では縦組みが読めるかどうかが選定条件になるため、この 2 語は露出枠として大きい。

あわせて、日本語の概要にも縦組みで読める旨を追記する余地がある(現状は未記載)。
検索で来た読者が製品ページで確認できないと、キーワードだけ当てても転換しない。

### キーワードに入れない語(未対応)

- `自炊` `PDF`: PDF 非対応。誤解を招くため使わない
- `読み上げ`: TTS 非対応

掲載語はすべて実装済み機能に対応する(`全文検索` `しおり` `目次` `同期` は
`ReaderScreen` のツールバーおよび v1.7 の iCloud 同期で確認済み)。

## 説明文(日本語・最大 4000 字)

配信中の文面に 2 点を追加した版。App Store Connect の日本語ロケールへ貼る。

追加点は次の 2 つ。

1. **縦書き対応の明記**。新しいキーワード `縦書き` `青空文庫` で検索して来た読者が、
   製品ページで裏付けを見つけられないと転換しない
2. **無料で 1 回書き出せることの明記**。配信中の文面は書き出しを Pro 限定と書いており、
   v1.10 の挙動と食い違う

```
Leafmark は、じっくり読んでメモを取る人のための、シンプルで高速な EPUB リーダーです。

一度購入すれば永久に使えます。サブスクリプション不要、アカウント不要、クラウドロックインなし。あなたのライブラリはデバイス上のプレーンな EPUB ファイルで、ハイライトはいつでもエクスポートできます。

読書を楽しむ
・リフロー型 EPUB レンダリング（ライト・セピア・ダークテーマ）
・縦書きの日本語書籍にも対応。青空文庫の EPUB など、縦組み指定のある本はそのまま縦書きで表示します
・フォント、サイズ、行間、余白を自由に調整
・1カラム・2カラム表示、スクロールモード対応（iPadのランドスケープに最適）
・全文検索、目次ナビゲーション、内蔵辞書
・本ごとに読書位置を記憶

注釈してノートを持ち出す
・4色のハイライトとノート
・すべてのハイライトとノートを Markdown でエクスポート — Obsidian、Notion、任意のプレーンテキスト環境に直接貼り付け
・読書統計: 今日・今週・累計の読書時間、ストリーク、本ごとの進捗

プライバシー重視の設計
・アカウント不要、サインイン不要
・トラッキングなし、アナリティクスなし
・すべてのデータはデバイス上に保持

Leafmark Pro
読書は永久無料。ライブラリをインポートし、好きな本をレンダリングし、使い心地を確かめてから購入を決められます。Markdown エクスポートも無料で1回試せるので、手元のノートに何が入るかを確かめてから判断できます。買い切りの Leafmark Pro で、無制限ハイライト（無料版は1冊あたり3件まで）、無制限の Markdown エクスポート、読書統計がアンロックされます。いつでも購入を復元できます。

便利な情報
・Files アプリから直接インポート — iCloud Drive、Google Drive、Dropbox 対応
・DRM フリーの EPUB ファイルに対応。DRM 付き書籍と PDF には非対応
・パブリックドメインの EPUB は青空文庫、Public Domain Library、Standard Ebooks で入手可能
```

## カテゴリ

- 主: Books
- 副: Productivity(Markdown エクスポート × PKM 層の訴求。go-to-market.md チャネル 5)

## What's New(v1.4)

```
New installations now include three public-domain classics.
The titles are Frankenstein, Meditations, and The Autobiography of Benjamin Franklin.
The empty library also links to Public Domain Library, making it easier to find more free EPUBs.
```

## 審査メモ(App Review への補足)

```
- No account or login is required; all data stays on device.
- In-app purchase "Leafmark Pro" (com.atani.inkwell.pro) is a single non-consumable, one-time unlock — not a subscription. It unlocks unlimited highlights, Markdown export and reading statistics. Restore is available on the Leafmark Pro screen.
- The app reads DRM-free EPUB files supplied by the user.
- Three public-domain samples from Standard Ebooks are included.
  The titles are Frankenstein, Meditations, and The Autobiography of Benjamin Franklin.
```

## 文字数チェック(申請前に再確認)

| 項目 | 上限 | 状態 |
|---|---|---|
| App 名 | 30 | 22 字 ✅ |
| サブタイトル | 30 | 25 字 ✅ |
| プロモテキスト | 170 | 156 字 ✅ |
| キーワード | 100 | 99 字 ✅ |
| 説明文 | 4000 | 余裕あり ✅ |
