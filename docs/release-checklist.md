# App Store 申請チェックリスト

Leafmark を App Store に出すまでの確認項目をまとめる。Apple Developer
Program 登録済み(承認待ち)。承認が下りたら上から順に潰していく。

関連ドキュメント: 価格方針は [ADR-0005](adr/0005-buy-once-pricing-storekit.md)、
販売戦略は [go-to-market.md](go-to-market.md)、プライバシーは
[privacy-policy.md](privacy-policy.md)。

## 1. ビルド・技術要件

- [ ] 🔴 **同梱サンプルを 10 ページ以上送り、ページ境界の表示を目視する**
      — フォントサイズを最小・既定・最大の 3 通りで確認する。
      次ページの先頭行が現在のページに重なっていないこと。
      v1.6〜v1.9 は Readium の `contentInset` を縮めたせいでこれが崩れており、
      MobileRead で 2 名が「アプリが使えない」と報告し App Store で 1 つ星が付いた。
      単体テスト 135 件はすべて通っていたため、テストでは捕まらない。
      レイアウトに触れる変更を含むリリースでは必須
- [x] 実機(andphoto / iOS 26.5)で署名ビルド・インストール・起動を確認
      — Team `3PC87Z3WVT` の Apple Development 署名。初回はデバイス側で
      開発者プロファイルの信頼が必要(Settings → General → VPN & Device Management)
- [ ] ハイライトのタップ動線(色変更・ノート編集・削除)を実機で確認
      — シミュレータでは座標タップで検証できず未確認のまま
- [x] iPhone・iPad 両方で起動とレイアウトを確認(`TARGETED_DEVICE_FAMILY: 1,2`)
      — iPhone 17(実機 andphoto)/ iPad Pro 13"(Simulator)で起動・レイアウト確認
- [x] 2 カラム表示(iPad)を確認 — iPad Pro 13" で `columnCount: 2` の 2 段組みを確認
      (`docs/screenshots/08-ipad-2column.png`)。ランドスケープでの最終撮影は手動
      (MCP では回転を自動化できず、システムロケールが日本語のため英語版は撮り直し)
- [x] ユニットテスト 19 件が pass する(`HighlightStore` / `StatsStore` /
      `StoreManager`)。`StorePurchase` の 3 件は SKTestSession が必要で
      ヘッドレス `xcodebuild test` ではスキップ(Xcode 実行時に検証)
- [x] リリースビルド(Release 構成)でクラッシュ・警告がないこと
      — Release ビルド成功・警告 0(iPad 全方向対応で orientation 警告も解消)
- [x] バージョン番号・ビルド番号を1.4 / 8に設定する。
      — `MARKETING_VERSION: 1.4` / `CURRENT_PROJECT_VERSION: 8`(project.yml)
- [x] 最低 OS バージョンが iOS 17.0 で間違いないこと(`IPHONEOS_DEPLOYMENT_TARGET: 17.0`)

## 2. App Store Connect のメタデータ

テキストの英語草案は [app-store-metadata.md](app-store-metadata.md) に用意済み。
App Store Connect への転記は Developer Program 承認後。

- [x] アプリ名: App Store 名 `Leafmark — EPUB Reader`(App Store Connect 受理済み)/
      `CFBundleDisplayName` は `Leafmark`(ホーム画面用に短縮。意図的に別)
- [ ] Bundle ID: `com.atani.inkwell`
- [x] サブタイトル(30 字)・プロモーションテキスト — 草案済み(25 字 / 156 字)
- [x] 説明文(英語)。訴求の軸は「買い切り・ロックインなし・エクスポート自由」
      (P2 × P8) — 草案済み
- [x] キーワード(EPUB / reader / highlight / annotation / Obsidian など) — 草案済み(91 字)
- [x] カテゴリ(Books を主、Productivity を副で検討) — 主 Books / 副 Productivity で確定
- [x] スクリーンショット(英語、6.9 インチ = 1320×2868 基準)
      — iPhone 17 Pro Max で 7 枚を `docs/screenshots/6.9-inch/` に用意済み
      (ライブラリ/表紙/本文/設定/ハイライト/統計/Pro)。iPad ランドスケープ版は手動で追加撮影
  - 撮影用の書籍はパブリックドメインの作品を使う。
    入手先はPublic Domain LibraryまたはStandard Ebooksとする。
    技術評論社の `Docker入門.epub` など著作物は申請素材に使わない
  - `xcrun simctl status_bar override` の `--time 9:41` 指定でステータスバーを整える
- [x] サポート URL: <https://atani.github.io/leafmark-app/support.html>
- [x] プライバシーポリシー URL: <https://atani.github.io/leafmark-app/privacy.html>
- [ ] App プライバシー(栄養成分表示): データ収集なし・トラッキングなしで申告
      — アカウントとクラウドを持たず端末内で完結するため

## 3. 課金(StoreKit 2 / Leafmark Pro)

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
      レーティングアンケートに再回答が必要。Leafmark は
      ユーザーが任意の EPUB を読み込めるため、**ユーザー生成・外部コンテンツ**
      の扱いに注意する。自前で成人向けコンテンツを同梱しなくても、
      外部読み込みの有無は正しく申告する
- [ ] **豪州・ベトナムのレーティング変更(2026-06-18〜)**: 両国向けの
      レーティング基準が更新される。対象国に配信するなら影響を確認
- [ ] **コピーキャット取り締まり強化**: 既存有名アプリ(MarginNote 等)の
      名称・アイコン・スクリーンショットに寄せていないか確認。Leafmark
      は独自名・独自アイコンで差別化できているが、説明文で他社名を
      不適切に使わないこと

## 5. 審査リジェクトを避ける確認

- [ ] DRM 付き EPUB / PDF 非対応であることを説明文に明記(誤解による低評価防止)
- [ ] サンプル EPUB を審査チームが入手できるようにする(パブリックドメイン
      EPUB の入手先 URL を審査メモへ記載)
- [ ] 端末内完結・アカウント不要をプライバシー申告と説明文で一致させる
- [ ] 外部リンク(GitHub Issues)が機能し、サポート手段として成立していること
- [ ] アプリ内に未完成機能・プレースホルダ・「Coming soon」表示がないこと

## 6. 申請手順(承認後の操作順)

Developer Program の本人確認は 2026-06-13 受付・2 営業日以内に連絡(6/16〜6/17 見込み)。
**有効化されたら上から順に実行する**。IA(課金)があるため、税・銀行が販売開始の関門になる。

1. [ ] **Program License Agreement に同意**(App Store Connect / Account Holder)
       — 未同意だと submit 不可
2. [ ] **Agreements, Tax, and Banking** を完了 — **IAP の必須関門**
   - [ ] Paid Applications Agreement(有料/IAP 用契約)に同意
   - [ ] 税務フォーム(W-8BEN 等)を提出
   - [ ] 銀行口座を登録 — これが揃わないと Leafmark Pro が販売可能にならない
3. [ ] **Small Business Program に登録**(手数料 15%。ADR-0005)
4. [x] **アプリレコード作成**: 名称 `Leafmark — EPUB Reader` / Bundle ID `com.atani.inkwell` /
       プライマリ言語 英語 / SKU 任意(App Store Connect で作成済み)
5. [ ] **非消費型 IAP を登録**: `com.atani.inkwell.pro`($9.99 = 提出時の Tier)。
       表示名・説明・審査用スクショ・審査メモ(`app-store-metadata.md` の審査メモ)を設定。
       **初回は IAP をアプリのバージョンに添付して同時審査に出す**
6. [ ] **ビルドを upload**: Xcode で Release アーカイブ → Distribution 署名 →
       App Store Connect へ(または Transporter)。バージョン 1.0 / ビルド 1
7. [ ] **メタデータ入力**(`app-store-metadata.md` から転記): 名称/サブタイトル/プロモ/
       説明/キーワード/カテゴリ(Books 主・Productivity 副)
8. [ ] **スクリーンショットをアップロード**: `docs/screenshots/6.9-inch/` の 7 枚(1320×2868)
9. [ ] **App プライバシー(栄養成分)**: データ収集なし・トラッキングなしで申告(§2 と一致)
10. [ ] **年齢レーティングアンケート**に回答(2026-07 新分類。外部 EPUB 読み込みの扱いに注意。§4)
11. [ ] サポート URL / プライバシーポリシー URL を設定(§2):
       サポート = `https://atani.github.io/leafmark-app/support.html`
       プライバシー = `https://atani.github.io/leafmark-app/privacy.html`
12. [ ] **審査提出**(アプリ + IAP を同時に)。§5 のリジェクト回避チェックを最終確認
13. [ ] 審査通過後、リリース(手動公開 or 自動公開を選択)
