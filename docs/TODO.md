# TODO / ロードマップ

顧客ペイン(docs/customer-pains.md)の P 番号に対応づけて管理する。

## v0.2(完了)

- [x] ハイライト・注釈(P2): 選択 → 色付きハイライト、ノート添付、一覧から削除・ジャンプ
- [x] ハイライトの Markdown エクスポート(P2): 共有シートから Obsidian / Notion へ
- [x] 辞書連携(P3): 選択 → システム辞書ルックアップ
- [x] 読書統計(P4): セッション自動記録、今日 / 週 / 累計、本ごと、連続日数

## v0.3(完了)

- [x] iPad ランドスケープの 2 カラム表示(P7): `columnCount` preference(Auto / 1 / 2)
- [x] 検索(本文全文検索 — Readium `SearchService`、上限 500 件)
- [x] スクロールモード切替(`scroll` preference)
- [x] 行間・余白の設定追加(P6 深掘り。行間は publisherStyles オフで有効化)
- [x] App アイコン(開いた本 + ハイライト。`docs/` ではなくスクリプト生成 → Assets.xcassets)

## v0.4 候補

- [ ] ハイライト色の追加とアンダーライン形式
- [ ] ページめくりアニメーション
- [ ] 両端揃え・文字間の設定追加
- [ ] 蔵書のコレクション・タグ整理(Marvin のスマートコレクション相当)
- [ ] オンボーディング・App Store スクリーンショット素材(英語)
  - 撮影用の書籍は**パブリックドメイン**(Standard Ebooks / Project Gutenberg)を使う。
    手元の `Docker入門.epub` は技術評論社の著作物なので表紙・本文を申請素材に使わない
  - サイズは 6.9"(1320×2868)を基準に。iPhone 17 Pro Max Simulator で撮る
  - `xcrun simctl status_bar override --time "9:41"` でステータスバーを整える

## v1.0 リリース準備

- [ ] iCloud 同期(位置・ハイライト・蔵書メタデータ)
- [ ] OPDS カタログ / Calibre 連携
- [ ] アクセシビリティ監査(VoiceOver / Dynamic Type)
- [x] 価格モデル決定(ADR-0005: 無料 DL + 非消費型 IAP「Inkwell Pro」$9.99。サブスクなし)
- [ ] StoreKit 2 課金実装(`StoreManager`・Pro 機能ゲーティング・購入復元。ADR-0005 の境界線)
- [ ] App Store 申請。「買い切り・ロックインなし・エクスポート自由」を訴求文の軸に(P2 × P8)

## 技術的負債

- [ ] `locationDidChange` ごとのカタログ全書き込みをデバウンス(ADR-0003)
- [x] ユニットテスト導入(HighlightStore / StatsStore のロジック。Tests/ + InkwellTests ターゲット。LibraryStore は Readium パース依存のため別途)
- [ ] 蔵書が増えた場合の SQLite 移行判断(ADR-0002 の見直し条件)
