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
Reading is always free. Import your library, render any book and try the feel before you decide. A single one-time purchase, Leafmark Pro, unlocks the full annotation workflow: unlimited highlights (the free tier keeps up to three per book), Markdown export, and reading statistics. Restore your purchase any time.

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

### ja(93 字 / 21 語)

```
電子書籍,ハイライト,注釈,読書,読書メモ,読書記録,マークダウン,オブシディアン,書き出し,蔵書,統計,買い切り,サブスクなし,広告なし,辞書,全文検索,しおり,目次,同期,洋書,引用
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

### キーワードに入れない語(未検証・未対応)

- `縦書き` `青空文庫`: 縦組みの明示的な対応コードが無く(`writing-mode` の grep で該当なし)、
  同梱サンプルも英語 3 冊のみ。動作を検証するまで使わない。検証できれば日本語圏で大きな枠になる
- `自炊` `PDF`: PDF 非対応。誤解を招くため使わない
- `読み上げ`: TTS 非対応

掲載語はすべて実装済み機能に対応する(`全文検索` `しおり` `目次` `同期` は
`ReaderScreen` のツールバーおよび v1.7 の iCloud 同期で確認済み)。

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
