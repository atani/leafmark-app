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

## ユーザー要望（リリース後のフィードバック）

出所と「無いと移行できない機能」かどうかをタグで残す（go-to-market 6. 指標）。

- [ ] ユーザーフォントの持ち込み（.ttf / .otf インポート → フォントピッカーに追加）
      — 出所: MobileRead t=374295 JSWolf(2026-07-06)。同氏は ScrollWizard スレッドでも同じ要求
      をしており、この層の定番要件。【移行ブロッカー候補】Readium の
      `fontFamilyDeclarations` で技術的に実現可能なことは確認済み
- [ ] フォント weight（太さ）調整 — 出所: 同上。Readium が可変フォントの weight を
      公開しているか要調査。持ち込みフォント対応とセットで検討
- [ ] ブックマーク（複数ページに印を付けて一覧からジャンプ）— 出所: MobileRead t=374295
      (2026-07-07、Leafmark を試した好意的レビューで要望)。現状は読書位置の自動保存のみで
      明示ブックマークは無い。Marvin にあった定番機能。HighlightStore と同型の BookmarkStore +
      ツールバー導線 + 一覧シートで実現見込み。v1.6 の有力候補
- [ ] 画像の全画面表示・ピンチズーム — 出所: 同上。
      要望は画像を全画面まで拡大したいという内容。現状は画像タップ非対応（`didTapAt` は chrome トグルのみ）。
      実装には JS で elementFromPoint による画像ヒットテスト + src 取得 → ズーム可能ビューア提示が必要。
      挿絵の多い EPUB で効く

## upstream 待ち（合成ウェイトの置き換え）

アプリ内の合成ウェイト実装（PR
[#26](https://github.com/atani/epub-reader-ios/pull/26)、`-webkit-text-stroke` 方式）を、
将来 upstream 側の設定に置き換える。

**経緯（2026-07 時点）**: swift-toolkit 向けの実装 PR
[#854](https://github.com/readium/swift-toolkit/pull/854) はメンテナ（mickael-menu）が
クローズ。「各ツールキット個別ではなく Readium CSS 本体に入れるべき」との方針
（issue [#853](https://github.com/readium/swift-toolkit/issues/853) は open のまま、
JayPanoz の設計判断待ち）。

**置き換えトリガー（時期未定）**: readium-css に `fontWeightSynthesis` 相当が入る →
swift-toolkit が取り込む → タグリリース、の順。リリースを確認してから以下を実施する。
`from` 指定への復帰（issue #18 の後始末）は、この置き換えとは独立に、#845 を含む
安定版タグ（3.11 以降）が出た時点で先行して進めてよい。

- [ ] Readium 依存を安定版タグ（3.11 以降）へ更新する
  - `project.yml` の `revision: 8811f0e...` を `from: "3.11.0"` 相当へ戻す
    （コメントに記載済みの issue #18 の後始末と同時に完了する）
  - `Leafmark.xcodeproj/project.pbxproj` の `kind = revision` も `upToNextMajorVersion` に戻す
- [ ] （upstream に合成ウェイトが入った後）アプリ内ワークアラウンドを削除する
  - `Sources/SyntheticWeight.swift` と `Tests/SyntheticWeightTests.swift` を削除
  - sentinel ファミリー `-leafmark-synthetic-weight` の注入配線
    （`FontStore` / `ReaderScreen` 側）を削除
  - `project.pbxproj` から両ファイルのエントリを削除
- [ ] `AppearanceStore.preferences` で `fontWeightSynthesis: true` を設定する
  （>1.0 の判定と em スケーリングは upstream 側が行う）
- [ ] 「ストローク変更は本を開き直すと反映」の注記コメント・挙動を撤去する
  （upstream 経路は `readium.setCSSProperties` によるライブ更新のため、開き直し不要になる）
- [ ] 検証: インポートフォント（単一フェイス）で weight 100/150/250% がライブに変わること、
  Georgia の実 Bold フェイス切替が壊れていないこと、ダークテーマでストローク色が文字色に
  追従すること（currentColor）
- [ ] 検証手法メモ: シミュレータの設定書き換えはアプリコンテナ内 plist を
  シミュレータ shutdown 中に plistlib で編集 → boot（`simctl spawn defaults write` は
  グローバル設定に書いてしまい、アプリには届かない）

## v0.4 候補

- [x] クラウド取り込み(Google Drive 等): 専用 SDK は持たず標準 Files プロバイダ経由に決定(ADR-0006)。
      `.fileImporter` が Drive / iCloud / Dropbox を既にカバー。説明文に明記済み
- [ ] フォーマット拡張の検討: PDF は注釈パリティ期待 + MarginNote 競合のリスクがあり read-only で v1.1+。
      Marvin も PDF 非対応で EPUB + CBZ/CBR のみだったため、Marvin パリティなら CBZ/CBR が優先。ベータで実需確認
- [ ] ハイライト色の追加とアンダーライン形式
- [ ] ページめくりアニメーション
- [ ] 両端揃え・文字間の設定追加
- [ ] 蔵書のコレクション・タグ整理(Marvin のスマートコレクション相当)
- [ ] ライブラリのソート(タイトル / 著者 / 追加順)とシリーズ表示 — 出所: MobileRead t=374295
      The Old Man(2026-07-16、「自分は十数冊なので不要だが、いずれ必要になる」)。
      ソートは軽いので先行実装候補、シリーズ / コレクションは v0.4 のコレクション整理と統合
- [ ] オンボーディング・App Store スクリーンショット素材(英語)
  - 撮影用の書籍はパブリックドメインの作品を使う。
    入手先はPublic Domain LibraryまたはStandard Ebooksとする。
    手元の `Docker入門.epub` は技術評論社の著作物なので、表紙・本文を申請素材に使わない
  - サイズは 6.9 inch(1320×2868)を基準に。iPhone 17 Pro Max Simulator で撮る
  - `xcrun simctl status_bar override --time "9:41"` でステータスバーを整える

## v1.0 リリース準備

- [ ] 蔵書カタログのメタデータ同期 + 再インストール時の復元候補表示 — 出所: 実ユーザー検証
      (2026-07-20)。再インストールで蔵書が消えサンプルだけ戻るのは「データ消失」に見える。
      EPUB 本体は同期せず、contentKey + タイトルのカタログだけ同期して「他の端末にある本」を
      提示 → 入れ直しでハイライト復元(v1.8 実装中、feature/catalog-sync)
- [x] iCloud 同期(位置・ハイライト・しおり) — v1.7 で出荷(ADR-0007)。蔵書メタデータ /
      EPUB ファイル本体の同期はスコープ外として残(ADR-0007 の見直し条件)
- [ ] OPDS カタログ / Calibre 連携
- [ ] アクセシビリティ監査(VoiceOver / Dynamic Type)
- [x] 価格モデル決定(ADR-0005: 無料 DL + 非消費型 IAP「Leafmark Pro」$9.99。サブスクなし)
- [x] StoreKit 2 課金実装。
      `StoreManager`・Paywall・Pro 機能ゲーティング・購入復元を実装。
      ADR-0005 の境界線。`Leafmark.storekit` を scheme Run に紐付け
  - XcodeBuildMCP でゲーティング動線と Pro 画面を確認・撮影。
    無料枠超過・統計・エクスポートで `PaywallView` を提示する
  - 実購入の目視確認は未実施。
    XcodeBuildMCP / `simctl launch` では StoreKit 設定の商品が配信されず、購入ボタンが非活性。
    Xcode の Run か App Store Connect への IAP 登録後に検証する
  - Pro 画面の撮影は DEBUG 限定の `-leafmarkForcePro` launch 引数(`StoreManager`)で解放。リリースには非搭載
  - 購入フローの自動テストは headless `xcodebuild test` では SKTestSession が config の商品を配信しないためスキップ(Xcode 実行時は有効)
- [ ] App Store 申請。「買い切り・ロックインなし・エクスポート自由」を訴求文の軸に(P2 × P8)

## 技術的負債

- [ ] `locationDidChange` ごとのカタログ全書き込みをデバウンス(ADR-0003)
- [x] ユニットテスト導入。
      HighlightStore / StatsStore のロジックを Tests/ + LeafmarkTests ターゲットで検証。
      LibraryStore は Readium パース依存のため別途
- [ ] 蔵書が増えた場合の SQLite 移行判断(ADR-0002 の見直し条件)
