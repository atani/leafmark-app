# ADR-0002: ライブラリはファイルベース(JSON カタログ + Documents 配下のフラット配置)にする

- Status: Accepted
- Date: 2026-06-11

## Context

書籍ファイル・メタデータ・読書位置・ハイライト等をどう永続化するか。SQLite(GRDB)、Core Data、SwiftData、ファイルベースを検討した。

## Decision

v1 はファイルベースにする。

- `Documents/Books/<uuid>.epub` — 取り込んだ書籍本体(iCloud バックアップ対象)
- `Library/Application Support/library.json` — カタログ(`[Book]` の JSON)
- `Library/Application Support/Covers/<uuid>.png` — カバーサムネイル
- 読書設定(テーマ・フォント)は UserDefaults
- 読書位置は Book レコード内に Locator JSON 文字列として保持

## Rationale

- 蔵書数は個人利用で高々数百冊。全件ロードしても JSON で十分速い
- スキーママイグレーションを Codable の optional フィールド追加だけで済ませられる
- DB 層が無いことでコード量・依存・デバッグコストを最小化できる(spike からの進化速度を優先)

## Consequences

- 横断検索(全文・ハイライト横断)が必要になった時点で SQLite(GRDB)への移行を検討する
- カタログ書き込みは atomic write(`.atomic`)で破損を防ぐ
- 数千冊規模・差分同期(iCloud/Dropbox)を入れる場合はこの設計を見直す(その時は ADR を追加)
