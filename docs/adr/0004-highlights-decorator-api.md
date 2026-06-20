# ADR-0004: ハイライト・注釈は Readium Decorator API + JSON ストアで実装する

- Status: Accepted
- Date: 2026-06-11

## Context

ハイライト・注釈は Marvin 難民の中核要求(顧客ペイン P2)。描画方式と永続化方式を決める。

検討した選択肢:

1. **Readium Decorator API**(`DecorableNavigator.apply(decorations:in:)`)+ 自前モデル
2. WKWebView に独自 JS を注入して Range ベースで描画
3. ハイライトを本文 HTML に直接書き込む(改変)

## Decision

Readium Decorator API を使う。

- 選択メニュー: `EPUBNavigatorViewController.Configuration.editingActions` にカスタム `EditingAction`(Highlight / Note)を追加。セレクタは navigator を包むコンテナ `UIViewController`(responder chain)で受ける
- 位置: `SelectableNavigator.currentSelection` の `Locator` をそのまま保存(ADR-0003 と同じ JSON 形式)
- 描画: `Decoration(style: .highlight(tint:))` を `apply(decorations:in: "highlights")` で一括宣言。タップは `observeDecorationInteractions` で受ける
- 永続化: `Library/Application Support/highlights.json` に全ハイライトを JSON 保存(ADR-0002 のファイルベース方針を踏襲)
- エクスポート: Markdown 文字列を生成して共有シートへ(Obsidian / Notion 想定)

## Rationale

- Decorator API は差分描画・リフロー追従・複数 WebView(章)跨ぎを Readium 側が面倒みてくれる。自前 JS 注入はこれを全部再実装することになる
- 本文改変方式は元ファイルの不変性を壊し、エクスポート・再パースで事故る
- 辞書連携(P3)は `EditingAction.defaultActions` に含まれる `.lookup`(iOS ネイティブの Look Up)をそのまま残すことで追加実装なしに提供する

## Consequences

- ハイライトの結合・分割(重なり選択)は対応しない(Marvin もしていない)。同一範囲の重複作成は可能だが実害は小さい
- 横断検索・件数が増えた場合の性能は ADR-0002 の SQLite 移行判断に含める
- `UIMenuItem` ベースの EditingAction は iOS の Edit Menu 移行(UIEditMenuInteraction)で将来 Readium 側 API が変わる可能性がある
