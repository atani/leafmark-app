# App Store 申請チェックリスト

Inkwell Reader を App Store に出すまでの確認項目をまとめる。Apple Developer
Program 登録済み(承認待ち)。承認が下りたら上から順に潰していく。

関連ドキュメント: 価格方針は [ADR-0005](adr/0005-buy-once-pricing-storekit.md)、
販売戦略は [go-to-market.md](go-to-market.md)、プライバシーは
[privacy-policy.md](privacy-policy.md)。

## 1. ビルド・技術要件

- [ ] 実機(Apple Developer Program 承認後)でビルド・起動を確認
- [ ] ハイライトのタップ動線(色変更・ノート編集・削除)を実機で確認
      — シミュレータでは座標タップで検証できず未確認のまま
- [ ] iPhone・iPad 両方で起動とレイアウトを確認(`TARGETED_DEVICE_FAMILY: 1,2`)
- [ ] ランドスケープの 2 カラム表示(iPad)を確認
- [x] ユニットテスト 19 件が pass する(`HighlightStore` / `StatsStore` /
      `StoreManager`)。`StorePurchase` の 3 件は SKTestSession が必要で
      ヘッドレス `xcodebuild test` ではスキップ(Xcode 実行時に検証)
- [ ] リリースビルド(Release 構成)でクラッシュ・警告がないこと
- [ ] バージョン番号・ビルド番号を設定(初回は 1.0 / 1)
- [ ] 最低 OS バージョンが iOS 17.0 で間違いないこと

## 2. App Store Connect のメタデータ

- [ ] アプリ名: Inkwell Reader(`CFBundleDisplayName` と一致)
- [ ] Bundle ID: `com.atani.inkwell`
- [ ] サブタイトル(30 字)・プロモーションテキスト
- [ ] 説明文(英語)。訴求の軸は「買い切り・ロックインなし・エクスポート自由」
      (P2 × P8)
- [ ] キーワード(EPUB / reader / highlight / annotation / Obsidian など)
- [ ] カテゴリ(Books を主、Productivity を副で検討)
- [ ] スクリーンショット(英語、6.9 インチ = 1320×2868 基準)
  - 撮影用の書籍は**パブリックドメイン**(Standard Ebooks / Project Gutenberg)を使う。
    技術評論社の `Docker入門.epub` など著作物は申請素材に使わない
  - `xcrun simctl status_bar override` の `--time 9:41` 指定でステータスバーを整える
- [ ] サポート URL: <https://github.com/atani/epub-reader-ios/issues>(support.md)
- [ ] プライバシーポリシー URL(privacy-policy.md を公開ページとして配置)
- [ ] App プライバシー(栄養成分表示): データ収集なし・トラッキングなしで申告
      — アカウントとクラウドを持たず端末内で完結するため

## 3. 課金(StoreKit 2 / Inkwell Pro)

ADR-0005 に従う。アプリ側の課金実装は完了。残りは App Store Connect 側の登録作業。

- [x] StoreKit 2 実装(`StoreManager`: 商品ロード・購入・`currentEntitlements`
      監視・`AppStore.sync()` 復元)
- [ ] 非消費型 IAP `com.atani.inkwell.pro`($9.99)を App Store Connect に登録
- [x] Pro 機能のゲーティング(無料枠ハイライト 3 件・エクスポート/統計のロック)
- [x] 購入復元(`AppStore.sync()`)を Paywall(`PaywallView`)に配置 — Apple 審査要件
- [ ] Small Business Program(手数料 15%)に登録
- [ ] IAP の審査用メモに「非消費型・買い切り・サブスクなし」を明記
- [ ] IAP はアプリ本体とは別レビュー。スクリーンショット・審査メモを別途用意

> MVP を「読む機能だけの無料アプリ」で先に出し、課金は次バージョンで載せる選択肢もある。
> その場合は本セクションを次回申請に回し、§1・§2・§4 だけで申請する。

## 4. 2026 年 7 月以降の制度変更(2026-06-13 時点の情報)

申請タイミングによっては以下の対応が必須になる。

- [ ] **年齢レーティングの新分類(2026 年 7 月〜)**: 従来の 4 区分から
      13+ / 16+ / 18+ を加えた区分に細分化される。App Store Connect で
      レーティングアンケートに再回答が必要。Inkwell Reader は
      ユーザーが任意の EPUB を読み込めるため、**ユーザー生成・外部コンテンツ**
      の扱いに注意する。自前で成人向けコンテンツを同梱しなくても、
      外部読み込みの有無は正しく申告する
- [ ] **豪州・ベトナムのレーティング変更(2026-06-18〜)**: 両国向けの
      レーティング基準が更新される。対象国に配信するなら影響を確認
- [ ] **コピーキャット取り締まり強化**: 既存有名アプリ(MarginNote 等)の
      名称・アイコン・スクリーンショットに寄せていないか確認。Inkwell Reader
      は独自名・独自アイコンで差別化できているが、説明文で他社名を
      不適切に使わないこと

## 5. 審査リジェクトを避ける確認

- [ ] DRM 付き EPUB / PDF 非対応であることを説明文に明記(誤解による低評価防止)
- [ ] サンプル EPUB を審査チームが入手できるようにする(パブリックドメイン
      EPUB の入手先 URL を審査メモへ記載)
- [ ] 端末内完結・アカウント不要をプライバシー申告と説明文で一致させる
- [ ] 外部リンク(GitHub Issues)が機能し、サポート手段として成立していること
- [ ] アプリ内に未完成機能・プレースホルダ・「Coming soon」表示がないこと
