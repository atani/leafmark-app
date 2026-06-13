# App Store メタデータ草案(英語)

App Store Connect 申請用のテキスト草案。承認が下りたら App Store Connect に転記する。
訴求軸は買い切り・ロックインなし・エクスポート自由(customer-pains.md P2 × P8)。
無料/有料の境界線は [ADR-0005](adr/0005-buy-once-pricing-storekit.md) に従う。

> 注: go-to-market.md §2 は旧案で「無料は蔵書 3 冊まで」と書いてあるが、ADR-0005 が
> 「読書体験は永久無料・課金境界は注釈ワークフロー(ハイライト 3 件 / エクスポート / 統計)」に
> 上書き済み。実装も ADR-0005 準拠。本メタデータは ADR-0005 に合わせる。go-to-market.md §2 は別途更新する。

## App 名(最大 30 字)

```
Inkwell Reader
```

`CFBundleDisplayName` と一致(14 字)。

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
Inkwell Reader is a calm, fast EPUB reader for people who read closely and take their notes with them.

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

INKWELL PRO
Reading is always free. Import your library, render any book and try the feel before you decide. A single one-time purchase, Inkwell Pro, unlocks the full annotation workflow: unlimited highlights (the free tier keeps up to three per book), Markdown export, and reading statistics. Restore your purchase any time.

GOOD TO KNOW
• Works with DRM-free EPUB files. DRM-protected books and PDF are not supported.
• Public-domain EPUBs are available from Standard Ebooks and Project Gutenberg.
```

## キーワード(最大 100 字・カンマ区切り・スペース無し)

```
epub,reader,ebook,highlight,annotation,markdown,obsidian,notion,reading,notes,export,marvin
```

- 申請前に 100 字以内を必ず確認する(現状の概算 90 字前後)。
- `marvin` は ASO で indexed demand を取る狙い(go-to-market.md §1)。ただし他社名・商標を
  キーワードに入れるとリジェクト/削除されるリスクがある。残すかは申請前に判断する。

## カテゴリ

- 主: Books
- 副: Productivity(Markdown エクスポート × PKM 層の訴求。go-to-market.md チャネル 5)

## What's New(v1.0)

```
First release. A buy-once EPUB reader with highlights, Markdown export, reading statistics, and a privacy-first, on-device design.
```

## 審査メモ(App Review への補足)

```
- No account or login is required; all data stays on device.
- In-app purchase "Inkwell Pro" (com.atani.inkwell.pro) is a single non-consumable, one-time unlock — not a subscription. It unlocks unlimited highlights, Markdown export and reading statistics. Restore is available on the Inkwell Pro screen.
- The app reads DRM-free EPUB files supplied by the user. A public-domain sample (Peter and Wendy, J. M. Barrie) is available from Standard Ebooks: https://standardebooks.org/
```

## 文字数チェック(申請前に再確認)

| 項目 | 上限 | 状態 |
|---|---|---|
| App 名 | 30 | 14 字 ✅ |
| サブタイトル | 30 | 25 字 ✅ |
| プロモテキスト | 170 | 156 字 ✅ |
| キーワード | 100 | 91 字 ✅ |
| 説明文 | 4000 | 余裕あり ✅ |
