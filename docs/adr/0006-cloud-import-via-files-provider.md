# ADR-0006: クラウド取り込みは標準 Files プロバイダに委ね、専用 SDK を持たない

- Status: Accepted
- Date: 2026-06-14

## Context

「Google Drive からの EPUB インポートに対応したい」という要望があった。
取り込み元として Google Drive / iCloud Drive / Dropbox / OneDrive などのクラウドストレージが想定される。

実装方式の候補:

1. **専用 SDK 連携**: Google Drive SDK + Google OAuth を組み込み、アプリ内から Drive を直接参照する
2. **標準 Files プロバイダ経由**: iOS の `UIDocumentPicker`(SwiftUI の `.fileImporter`)に委ねる

現在の取り込みは既に `.fileImporter(allowedContentTypes: [.epub])` を使っており、これは
iOS の書類ブラウザ(Files)を開く。Files の「ブラウズ」には、対応アプリがインストール済みなら
**Google Drive / Dropbox / OneDrive などが「場所(File Provider)」として自動的に並ぶ**。
つまり Drive アプリが入った端末では、追加実装なしで Drive 上の EPUB を選んで取り込める。

## Decision

**専用のクラウド SDK 連携は実装しない。クラウドからの取り込みは標準の Files プロバイダ
(`UIDocumentPicker` / `.fileImporter`)に委ねる。**

- Google Drive / iCloud Drive / Dropbox / OneDrive 等は、各アプリの File Provider 拡張を
  通じて Files ピッカーに現れる。ユーザーはそこからファイルを選ぶだけでよい
- アプリは選択された security-scoped URL をコピーする既存フローをそのまま使う
  (`LibraryStore.importEPUB` の `startAccessingSecurityScopedResource` → `copyItem`)
- 訴求文には「iCloud / Google Drive / Dropbox など、Files が届く場所ならどこからでも取り込める」
  と一言添える

## Rationale

- **プライバシー方針(ADR-0002 / go-to-market.md)と矛盾しない**。専用 Drive 連携は
  Google OAuth = アカウント + クラウド + トラッキング能力を持つ SDK を抱え込むことになり、
  「No account. No tracking. No cloud.」「端末内完結」という訴求と App プライバシー申告
  (データ収集なし・トラッキングなし)を崩す。Files プロバイダ経由なら、認証も転送も OS と
  各プロバイダアプリ側で完結し、本アプリはアカウントも SDK も持たない
- **すでに動いている**。`.fileImporter` は iOS の書類ブラウザを開くため、Drive を含む全
  プロバイダを最初からカバーしている。専用実装は追加コストに対して得られる差分が小さい
- **保守コストが低い**。各クラウドの SDK・OAuth・API 変更に追従する負債を負わない
- 「Drive 全体を一覧/同期」のような双方向同期は別物の重い機能であり、v2 の iCloud 同期
  (TODO の v1.0 リリース準備)とまとめて検討する領域。単発の取り込みは Files で足りる

## Consequences

- クラウド取り込みのための新規コードは不要。既存の `.fileImporter` フローを維持する
- ユーザーは取り込み元アプリ(Google Drive 等)を端末にインストールし、Files の「場所」で
  有効化しておく必要がある。これは iOS 標準の挙動であり、アプリ側の責務ではない
- App Store 説明文・サポート文に「Files 経由で iCloud / Google Drive / Dropbox から取り込める」
  と明記する(`app-store-metadata.md`)。専用連携と誤解されないようにする
- 将来クラウド同期(蔵書・位置・ハイライト)を入れる場合は iCloud(端末内完結の延長)を第一候補とし、
  サードパーティクラウドの直接連携は本 ADR の方針に従い慎重に判断する
