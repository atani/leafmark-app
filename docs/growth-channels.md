# 流入チャネル別の投稿原稿

月間インプレッションが 1,000 しかないことが購入の律速になっている(`post-launch-kpi.md` 参照)。
App Store 検索だけでは母数が増えないため、対象読者が既にいる場所へ出す。

投稿は本人が行う。ここでは原稿と各コミュニティの作法だけを用意する。

## 共通方針

- 宣伝文体を使わない。これらのコミュニティは広告を即座に見抜いて反発する
- **制約を先に書く**(PDF 非対応・TTS 非対応・iOS のみ・DRM 付きは開けない)。
  後から発覚するより、最初に言ったほうが信頼される
- 買い切りであることは事実として一度だけ書く。繰り返すと宣伝になる
- 質問には実装の詳細で答える。ここが技術系コミュニティで効く

## 1. Show HN(Hacker News)

投稿条件は「作った本人」「実際に使える状態」。タイトルは `Show HN: ` で始める。
平日の米国朝(JST 22:00〜24:00)が動きやすい。

**タイトル案**

```
Show HN: Leafmark – An iOS EPUB reader that exports highlights as Markdown
```

**本文案**

```
I read a lot of EPUBs and take notes as I go, but the notes always ended up
stuck inside whichever reader I used. So I built Leafmark.

It is an iOS EPUB reader with one specific goal: whatever you highlight, you
can get back out as plain Markdown and drop into Obsidian, Notion, or any
folder of text files. No account, no server, no analytics SDK. Your books are
EPUB files on your device and the highlights live next to them.

Some details that might interest people here:
- Rendering is Readium 3 in a WKWebView, with the reading position stored per
  book as a locator rather than a page number, so it survives font changes.
- Highlights and reading positions sync between your own devices through
  iCloud Drive (CloudKit-free, just the user's own container), so there is no
  backend to trust and nothing for me to operate.
- Export is a plain Markdown file per book: title, author, then each highlight
  with its note.

Limitations, up front: EPUB only (no PDF), no text-to-speech, iOS/iPadOS only,
and DRM-protected books will not open. Reading is free; a one-time purchase
unlocks unlimited highlights, export and reading stats.

Happy to answer anything about the Readium integration or the sync design.
```

## 2. r/ObsidianMD

自作ツールの共有は許容されるが、Obsidian との接続点を具体的に示さないと弾かれる。
「Obsidian に何がどう入るか」を実例で見せるのが要点。**エクスポートした Markdown の実物を貼る**。

**タイトル案**

```
Built an iOS EPUB reader that exports highlights straight into my vault
```

**本文案**

```
I wanted my ebook highlights to end up in my vault without a clipper, an
account, or a sync service in between, so I ended up building the reader.

The export is a single Markdown file per book that looks like this:

    # Frankenstein
    Mary Shelley

    ## Highlights

    > Nothing is so painful to the human mind as a great and sudden change.

    Note: chapter 9 — this is the turn.

Drop it in your vault and your usual templates and dataview queries work on it,
because it is just text.

No account and nothing leaves the device except through your own iCloud Drive
if you turn sync on. EPUB only, no PDF, iOS and iPadOS.

Reading is free. If it is useful I would rather hear what breaks than get a
download — the export format in particular is easy to change while the user
base is small.
```

## 3. 🔴 Obsidian 公式フォーラム(Share & showcase)— 投稿しない

**当初この項目を投稿先として挙げたのは調査不足だった。規約を確認せずに書いていた。**

2026-07-26 に実際の投稿画面を開いたところ、カテゴリのテンプレートが次の警告で始まっていた。

> MUST READ - FAILURE TO FOLLOW THE RULES WILL LEAD TO A BAN
> Please, remember that the main purpose of this forum is to help Obsidian users.
> This goal should not be abused to advertise third-party projects.
>
> General Rules:
> - We will only accept Obsidian plugins, themes, CSS snippets, tips, and custom vaults
>   (workflow showcases).

Leafmark は iOS の EPUB リーダーであり、プラグインでもテーマでも CSS スニペットでもない。
third-party project の宣伝そのものに当たり、**アカウント BAN のリスク**がある。
プラグイン / テーマは community directory への登録も必須で、当然満たさない。

投稿は中止した。得られる露出より、アカウントを失う損失のほうが大きい。

### それでも Obsidian 層に届けたい場合

規約が認めている枠は **custom vaults(workflow showcase)** のみ。
アプリ紹介ではなく「EPUB のハイライトを vault に取り込むワークフロー」を主題にし、
Leafmark は手段として一度触れるだけにする必要がある。
それでも宣伝と判断される余地は残るため、実施するかは要判断。

r/ObsidianMD は別コミュニティで規約も別。そちらは自己宣伝ルールに従えば投稿可能。

## 4. MobileRead フォーラム

既に v1.5 でレビューを 2 件獲得している唯一の実績チャネル。
ここは EPUB の仕様に詳しい層なので、リリースごとに淡々と更新を出すのが合う。

**投稿案(v1.9 更新報告)**

```
Leafmark 1.9 is out. Since the last post here:

- Highlights, notes and reading positions now sync between your own devices
  through iCloud Drive. There is no server involved.
- Your library list syncs too, so after a reinstall the app can tell you which
  EPUBs you had. It does not move the files — you re-import them and the
  annotations reattach.
- Bookmarks, image zoom, and per-book reading statistics.

Still EPUB only and still DRM-free only. Feedback on the export format is
welcome.
```

## 5. Zenn(日本語・技術記事)

日本語圏で唯一まとまった読者を持つ自前チャネル。宣伝記事ではなく**技術記事として成立させる**。
アプリは記事の題材として登場させ、末尾で一度だけ触れる。

**タイトル案**

- 「iOS の EPUB リーダーを Readium 3 で作って、ハイライトを Markdown で取り出せるようにした」
- 「サーバーを持たずに iCloud Drive だけで iPhone と iPad の読書データを同期する」

**2 本目は全文を書き起こし済み**: `docs/drafts/zenn-icloud-sync.md`(textlint 通過済み)。
`published: false` にしてあるので、Zenn へコピーして中身を確認してから公開できる。

**構成案(2 本目のほうが読まれやすい)**

1. 課題: 読書ハイライトが各リーダーに閉じ込められる
2. 制約: アカウントもサーバーも持ちたくない(運用コストとプライバシー)
3. 設計: iCloud Drive のユーザーコンテナに注釈を置き、CloudKit を使わない理由
4. 実装: 競合解決をどうしたか、書き込みのフラッシュタイミング、ライブ監視
5. 詰まった点: 再インストール時にファイル実体が無いので蔵書カタログだけ別に同期した話
6. 結果と、まだ解けていない問題
7. 末尾に 1 行だけアプリのリンク

`~/.claude/rules/x-post-quality.md` に従い、X で告知する場合は URL 除き 120 字以内・ですます調。

## App Store レビューへの返信(US の 1★)

US ストアは評価 1 件・平均 1★。本文は v1.8 に対するもので、タイトルは
"Excellent ebook reader"、内容は「見込みはある。使いやすい。ただし現状は
バグでアプリが使えないので直してほしい」という趣旨。

製品自体は評価されているため、**具体的な症状を聞き出せれば復帰の見込みがある**。
1 件しか評価が無い状態で 1★ が居座ると、今後の全インプレッションの転換率を潰す。

返信案(App Store Connect の「デベロッパ返信」に貼る)。

```
Thank you for the kind words about the reader, and I am sorry it is not
working properly for you.

I would very much like to fix what you ran into, but I cannot tell from the
review which part is failing. If you have a moment, the support page below
takes a message and there is no account or sign-up involved — a sentence
about what you were doing when it broke, and which iOS version and device
you are on, is enough for me to reproduce it.

Version 1.9 is now out with fixes around library restore and re-importing
books. If your issue was there, it may already be resolved.

https://atani.github.io/leafmark-app/support.html
```

返信で避けること。

- 評価の変更を依頼しない(Apple のガイドライン上も避けるべきで、読み手の心証も悪い)
- 原因を推測して断定しない(実際まだ特定できていない)
- 言い訳や仕様説明を長く書かない。聞く姿勢だけを示す

### 解決済み(2026-07-26): 症状は split-page 不具合だった

上記は返信を書いた時点の記録で、その後に原因が判明した。

MobileRead のスレッドで 2 名が同じ症状を報告していた。ページを送ると次ページの
先頭行が現在のページに重なる不具合で、`ReaderView.swift` が Readium の
`contentInset` を上下 20pt に縮めていたことが原因(v1.6 以降の全バージョンに存在)。

1 つ星の "bugs that make the app unusable" はこれを指していたと考えられる。
修正は v1.10 でリリース済み。

**この経緯から得られた教訓**: 症状が分からないときは、App Store のレビューより
フォーラムのほうが具体的な情報が得られる。1 つ星が付いた時点で MobileRead の
既存スレッドを確認していれば、2 週間早く直せていた。

## 投稿順序

1. MobileRead(既存の実績チャネル。低リスクで即出せる)
2. r/ObsidianMD(対象読者の中心。Obsidian 公式フォーラムは規約により対象外)
3. Zenn(日本語圏。記事の準備に時間がかかる)
4. Show HN(一度しか使えない弾なので、上記のフィードバックで粗を取ってから)

Show HN を最後にするのは、失敗しても再投稿が効かないため。
先に小さいコミュニティで質問に答える練習をしてから出す。
