# ADR-0007: 注釈(ハイライト・ブックマーク・読書位置)は iCloud Drive でローカルファースト同期する

- Status: Accepted
- Date: 2026-07-16

## Context

Product Hunt ローンチで最も多かった要望が「iPhone と iPad でハイライト・ノート・ブックマーク・読書位置が揃ってほしい」だった。ADR-0006 は将来のクラウド同期について「iCloud(端末内完結の延長)を第一候補とし、その時は ADR を追加する」と明記していた。本 ADR がその追加である。

同期対象・非対象・保存方式・衝突解決を決める。

## Decision

注釈のみを、ユーザー自身の iCloud Drive(アプリの Documents コンテナ)経由でローカルファースト同期する。

- **同期する**: ハイライト(ノート・色を含む)、ブックマーク、本ごとの読書位置
- **同期しない**: EPUB 本体、読書統計、取り込みフォント、外観設定
- **v1 では UI を追加しない**: ゼロコンフィグ。ubiquity コンテナが使えるときに自動で有効、使えなければ静かに無効
- ローカルの JSON ストア(ADR-0002)を正とし、その上に**ミラー層**を重ねる。ミラーは注釈レコードを iCloud Documents コンテナへ書き出し、リモートの変更をローカルへマージし戻す

### 仕組み

- **コンテンツ安定キー**: `Book.id` は取り込みごとの UUID で端末間で異なる。代わりに EPUB バイト列の SHA-256(`contentKey`)を取り込み時に算出し、同期の突き合わせキーにする。既存蔵書は初回ロード時にファイルをハッシュして移行する(CryptoKit)
- **同期ドキュメント**: 本ごとに 1 ファイル `Documents/Annotations/<contentKey>.json`。`{highlights, bookmarks, position, schemaVersion}` を持つ。端末固有の `bookID` はドキュメントに含めず、マージし戻す際にローカル蔵書から付け直す
- **マージ**: レコード単位の last-writer-wins(`updatedAt`)+ 全ソースの和集合。削除は墓標(`deletedAt`)で伝播し、90 日を過ぎた墓標はマージ時に刈る。読書位置は単一レコードの LWW。マージは純関数(`AnnotationSyncMerge`)として切り出し網羅的に単体テストする
- **タイムスタンプ**: 新フィールドは optional Codable + バックフィル(`createdAt` か `.distantPast`)で、旧カタログをそのまま復号できる
- **ファイル協調**: コンテナの読み書きは NSFileCoordinator 経由。マージが冪等・可換なので、NSFileVersion の衝突は全バージョンを union-merge して解決する
- **変更検知**: NSMetadataQuery でリモート到着を監視し、ローカルミューテーション後(デバウンス)とアプリ復帰時にも push する
- **エンジン**: `SyncEngine`(MainActor ObservableObject)をアプリルートが所有し、各ストアに配線する。マージ適用時は echo ループを防ぐガードを置く

## Rationale

- **プライバシー方針(ADR-0002 / 0006)と矛盾しない**。データはユーザー自身の iCloud 内だけに置かれ、ベンダーアカウントも第三者サーバも SDK も持たない。「No account. No tracking. No cloud(vendor)」の訴求を崩さない
- **ローカルファースト**を保つことで、iCloud が無い・無効でもアプリは従来どおり動く。同期は付加価値であり必須ではない
- 本体 EPUB を同期対象から外すのは、容量・著作権・取り込み方針(ADR-0006 は Files 経由の単発取り込み)との整合のため。統計・外観・フォントは「端末ごと」が期待挙動に近い
- SHA-256 の contentKey により、同じ本を別端末で別々に取り込んでも注釈が突き合う

## Consequences

- iCloud Documents entitlement とコンテナ `iCloud.com.atani.inkwell` が必要(bundle id `com.atani.inkwell` は変更しない)。`NSUbiquitousContainers` は Info.plist に足さない(Files アプリに現れないようにする)
- 単一削除はローカルでも soft-delete(墓標)になり、公開読み取りは墓標を除外する。本ごと削除(蔵書からの削除)は墓標を残さない(他端末の注釈を消さないため)
- エンドツーエンドの iCloud 同期はヘッドレスで検証できない。純関数マージ・contentKey・復号互換は単体テストで、実機 2 台の突き合わせはメンテナが手動で検証する
- スキーマ変更時は `schemaVersion` を上げ、移行方針を追記する

## 追記 (2026-07-20): 蔵書カタログのメタデータも同期する

本 ADR で「EPUB 本体は同期しない」と決めたことの帰結として、再インストール後に取り込んだ本が消え、バンドルサンプルだけが戻るため**データ消失に見える**という利用者報告が出た(注釈は同じ EPUB を取り込み直せば `contentKey` 一致で復元されるが、どの本を取り込み直せばよいかを伝える手段が無かった)。

そこで**蔵書カタログのメタデータのみ**を追加で同期する(ファイルは引き続き同期しない、方針は不変)。

- **同期する(追加)**: 蔵書カタログのメタデータ 1 ドキュメント `Documents/Library/catalog.json`。`{schemaVersion, books: [{contentKey, title, author?, updatedAt, deletedAt?}]}`
- **依然として同期しない**: EPUB 本体・統計・フォント・外観設定
- **マージ**: 注釈と同一。`contentKey` をキーにレコード単位 LWW(`updatedAt`)+ 和集合 + 墓標(`deletedAt`)+ 90 日刈り。汎用の `AnnotationSyncMerge.mergeRecords` を再利用し、薄い純関数 `CatalogSyncMerge` で包む
- **復元候補の提示**: カタログにあってローカルに無い(かつ墓標でない)本を `LibraryView` 下部の "On your other devices" に静かに表示。行タップで既存のファイルインポータを開く
- **墓標**: 本のローカル削除は当該 `contentKey` に `deletedAt` を書き、新規インストールが誤って再提案しないようにする。ファイルはローカル正なので墓標は他端末のファイルを消さない(候補リストにのみ影響)。再取り込みは `updatedAt > deletedAt` で墓標を解除して復活する
- **保存**: マージ済みカタログは `books`(実在蔵書)を汚さないよう Application Support の別サイドカー JSON に持つ。エンジンは注釈と同じトリガー(デバウンス push・復帰・背景フラッシュ・NSMetadataQuery)に相乗りし、新しいタイマーは足さない。新規 entitlement は不要(コンテナは既存)
- エンドツーエンドの iCloud 検証はヘッドレス不可。マージ・候補導出・復号互換は単体テストで、実機の突き合わせはメンテナが手動で検証する
