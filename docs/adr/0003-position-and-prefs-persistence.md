# ADR-0003: 読書位置は Locator JSON、外観設定は UserDefaults で永続化する

- Status: Accepted
- Date: 2026-06-11

## Context

「アプリを閉じても同じページに戻る」は Marvin 難民の最低要求。位置の表現形式と保存先を決める。

## Decision

- 読書位置: Readium の `Locator` を `jsonString()` でシリアライズし、`Book.locatorJSON` に保存。復元は `Locator(json: JSONValue(jsonString:))`
- 外観設定(テーマ / フォントファミリー / フォントサイズ): `@AppStorage`(UserDefaults)でアプリ全体共通

## Rationale

- Locator は Readium 公式の位置表現で、章 href + progression + テキスト断片を含み、リフロー時にも頑健
- Readium 公式の JSON 形式をそのまま使うことで、将来のスキーマ互換(2.x → 3.x の legacyJSON 移行パスが用意されている)に乗れる
- 外観設定は「本ごと」ではなく「アプリ全体」が Marvin / Apple Books とも同じ挙動で、ユーザー期待に合う

## Consequences

- `locationDidChange` のたびにカタログ JSON 全体を書き直す。蔵書数百冊までは問題ないが、頻度が問題になればデバウンスを入れる
- 本ごとの設定オーバーライド(縦書き本だけ別フォント等)が必要になったら `Book` にオーバーライド用フィールドを足す
