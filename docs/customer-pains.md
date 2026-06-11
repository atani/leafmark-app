# 顧客ペイン: Marvin 難民(海外ユーザー)

メインターゲット: Marvin 3 が事実上開発停止になり代替を探している英語圏の熱心な読書家(MobileRead / Reddit r/ebooks に生息)。彼らは「読めるだけ」のアプリには戻れない。

## ペイン一覧(優先度順)

| # | ペイン | 現状の代替と不満 | 本アプリでの解消 |
|---|---|---|---|
| P1 | **Marvin がいつ動かなくなるか分からない**。App Store から消え、iOS アップデートのたびに怯える | 乗り換え先が無い | メンテされ続ける Marvin 代替を提供する(存在自体が解消) |
| P2 | **ハイライト・注釈がアプリにロックインされる**。Apple Books はエクスポート不可、Kindle は自炊 EPUB に使えない | コピペで手作業移植 | ハイライト + ノートを Markdown でエクスポート(Obsidian / Notion に直接貼れる形式) |
| P3 | **読書中に言葉を引くのが面倒**。辞書のためにアプリを離れたくない(英語圏ユーザーは語彙学習ニーズも強い) | Safari で検索しに行く | 選択 → システム辞書ルックアップを 1 タップで |
| P4 | **読書習慣が見えない**。Marvin の読書統計(時間・セッション)に依存していた | Apple Books は統計ほぼ無し | セッション自動記録 → 今日 / 週 / 累計・本ごと・連続日数 |
| P5 | **自炊・DRM フリー EPUB の取り込みが面倒**。iTunes 経由や 1 冊ずつの共有はだるい | Calibre からの転送が苦痛 | Files から複数インポート + Documents 直下自動取り込み + Open in |
| P6 | **外観の自由度が低い**。フォント・テーマ・行間をいじり倒したい層 | Apple Books は選択肢が少ない | テーマ 3 種 + フォント 5 種 + サイズ 70–200%(今後拡張) |
| P7 | **iPad ランドスケープで 2 カラム表示ができない**代替アプリへの不満 | Marvin にはあった。Apple Books は端末任せで制御不可 | Readium の `columnCount` preference で実装済み(Auto / 1 / 2 を設定で選択可) |
| P8 | **サブスク課金への反発**。BookFusion の年 $100 等、読書アプリの subscription 化に疲れている | 買い切りの選択肢が消えつつある | 価格モデルの明言: 買い切り・ロックインなし・エクスポート自由。P2 と束ねて App Store 訴求文の軸にする |

## 対応状況

- P1: 継続コミット(このリポジトリ)
- P2〜P7: 実装済み(ハイライト・注釈 + Markdown エクスポート / 辞書 / 統計 /
  インポート動線 / テーマ・フォント・行間・余白・スクロールモード / 2 カラム)。
  全文検索も実装済み
- P8: App Store 訴求文の軸として下記に明文化(価格設定の最終決定は申請時)

## App Store 訴求の軸(P2 × P8)

「Your highlights are yours.」— 機能の多さではなく**所有権**で訴求する。

- One-time purchase. No subscription.(年 $100 サブスクへの反発の受け皿)
- No lock-in: highlights & notes export to Markdown anytime.
- Your books stay yours: plain EPUB files, no proprietary library.

## まだ解消しないペイン(ロードマップは docs/TODO.md)

- シリーズ・コレクション・タグでの蔵書整理(Marvin のスマートコレクション)
- Calibre / OPDS 連携での取り込み
- iCloud 同期(複数デバイス間の位置・ハイライト共有)
