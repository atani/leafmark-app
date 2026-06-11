# ADR-0001: EPUB レンダリングに Readium Swift Toolkit を採用する

- Status: Accepted
- Date: 2026-06-11

## Context

Marvin 難民向け EPUB リーダーを作る。EPUB のパース・レンダリング・ページネーションを自作するか、既存ツールキットを使うかを決める必要がある。

検討した選択肢:

1. **Readium Swift Toolkit 3.x** — EPUB 標準化団体系の OSS。パーサ + WKWebView ベースのナビゲータ + Decoration(ハイライト)API
2. **WKWebView + 自作パーサ** — 完全な自由度。ただし spine 解決・CFI 相当の位置表現・ページネーション・縦書きを全部自作
3. **FolioReaderKit** — メンテ停止(最終リリースが古く Swift Concurrency 非対応)

## Decision

Readium Swift Toolkit 3.x を採用する。

## Rationale

- Locator(位置表現)、Decoration(ハイライト描画)、Preferences(テーマ/フォント)という、リーダーの中核 API が揃っており、Marvin 級の機能を最短で実装できる
- 3.0 で HTTP サーバ不要になり構成が単純化された(GCDWebServer アダプタは使わない)
- BSD ライセンスで商用利用可
- 活発にメンテされている(kobo などが採用)

## Consequences

- レンダリングは WKWebView ベース。ページめくりの細かい挙動は Readium の実装に依存する
- DRM(LCP)は必要になったら有償の lcp モジュール契約が別途必要
- Readium の API 変更(2.x → 3.x のような破壊的変更)に追従するコストを払う
