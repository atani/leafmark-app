# TODO / ロードマップ

顧客ペイン(docs/customer-pains.md)の P 番号に対応づけて管理する。

## v0.2(今回)

- [ ] ハイライト・注釈(P2): 選択 → 色付きハイライト、ノート添付、一覧から削除・ジャンプ
- [ ] ハイライトの Markdown エクスポート(P2): 共有シートから Obsidian / Notion へ
- [ ] 辞書連携(P3): 選択 → システム辞書ルックアップ
- [ ] 読書統計(P4): セッション自動記録、今日 / 週 / 累計、本ごと、連続日数

## v0.3 候補

- [ ] iPad ランドスケープの 2 カラム表示(P7): Readium `columnCount` preference。実装コスト低・Marvin 同等の差別化
- [ ] ハイライト色の追加とアンダーライン形式
- [ ] 検索(本文全文検索 — Readium `SearchService`)
- [ ] ページめくりアニメーション / スクロールモード切替(Readium `scroll` preference)
- [ ] 行間・余白・両端揃えの設定追加(P6 深掘り)
- [ ] 蔵書のコレクション・タグ整理(Marvin のスマートコレクション相当)
- [ ] App アイコン・オンボーディング・App Store 素材(英語)

## v1.0 リリース準備

- [ ] iCloud 同期(位置・ハイライト・蔵書メタデータ)
- [ ] OPDS カタログ / Calibre 連携
- [ ] アクセシビリティ監査(VoiceOver / Dynamic Type)
- [ ] App Store 申請。価格モデルは**買い切り**を明言する方向(P8: サブスク反発の受け皿。「買い切り・ロックインなし・エクスポート自由」を訴求文の軸に — customer-pains.md 参照。最終決定は要 ADR)

## 技術的負債

- [ ] `locationDidChange` ごとのカタログ全書き込みをデバウンス(ADR-0003)
- [ ] ユニットテスト導入(LibraryStore / HighlightStore / StatsStore のロジック)
- [ ] 蔵書が増えた場合の SQLite 移行判断(ADR-0002 の見直し条件)
