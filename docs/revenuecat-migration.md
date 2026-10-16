# RevenueCatの段階導入（既定無効）

RevenueCat 5.92.0を既存StoreKitと併用する実装です。StoreKitが購入・finish・購入復元・利用権の正本です。RevenueCatのCustomerInfoからProを付与/削除しません。商品ID・価格・無料枠・家族共有の判定を維持しています。

## 基点と商品

GitHubの`main`（`ef72b89e2a1b1a741654098170d9b1c450d5849b`）を基点にしています。
商品ID: `"com.atani.inkwell.pro"`。

公開1.17（build 26）に含まれる代替アイコン`AppIconPaperLeaf`を統合し、版番号を1.18（build 27）としました。公開ポリシー（`privacy.html`と`docs/privacy-policy.md`）へSDKを無効のまま同梱していることを記載済みです。

## 起動条件

`Config/RevenueCatDefaults.xcconfig`が既定値です。mode=disabled・キー空・4ゲートNOを維持します。
Debugは`RevenueCatDebug.xcconfig`から無視対象の`RevenueCatObserver.xcconfig`を任意で読みます。
Releaseは`RevenueCatRelease.xcconfig`から無視対象の`RevenueCatReleaseApproved.xcconfig`だけを任意で読みます。
実キーや承認済み設定はcommitしません。承認前は、これらのローカル設定を作らず既存課金を維持します。

`RevenueCatReleaseApproved.xcconfig.example`は無効な設定例です。
Releaseのビルド検査はbundle・公開SDKキー形式・4ゲートを確認し、不完全な有効化設定を拒否します。
設定値をビルド引数へ直接書かず、ログへ値を出しません。形式の検査は実接続の成功を意味しません。

- `REVENUECAT_DATA_SHARING_APPROVED`: SDKが自動取得する過去・継続のproduction/Sandbox購入履歴と匿名ID等の送信承認です。
- `REVENUECAT_INTEGRATION_READY`: app/bundle/public SDK key、IAP認証、全商品、復元と通知設定の確認です。
- `REVENUECAT_PRIVACY_READY`: 実装と公開ポリシー/ASC申告の一致確認です。
- `REVENUECAT_RELEASE_ENABLED`: Release版へ別途有効化する確認です。Debugでの接続には不要です。

これらに加えmode=observer、形式検査に通るpublic keyと一致bundleが必要です。テスト/Preview/demo/他bundleでは起動しません。Sandbox-onlyの旧modeでは起動しません。アプリのフィルタはSDK内部のTransaction.all/updates送信を制限しません。承認は8本分受領済みですが、外部設定/秘密鍵操作/プライバシー更新/公開を一括代行する承認として扱いません。

SDKは.myApp/.storeKit2で構成し、独自appUserIDや氏名/email/広告属性は追加しません。device identifierの自動収集を無効にし、購入情報を含むSDKログ出力を抑制します。既存SDKインスタンスの流用を拒否します。OFF設定はbuild時の起動防止です。起動済みSDKの停止機能ではありません。停止にはOFFビルドへの更新と再起動が必要です。

## 移行と障害

手動同期候補は検証済み・未返金・有効期限内の既存商品です。同期商品集合を顧客ID別のv2 namespaceへ保存し、集合の増加時は再同期します。購入時は保存成功を無効化し、世代番号が変わった古い応答を捨てます。失敗/カタログ不足を成功として保存しません。同時実行を抑制し、次回起動/明示復元で再試行できます。これはSDK自身の自動履歴送信を限定するものではありません。通信失敗でも既存StoreKitによる購入成功や利用権を変えません。

## 検証と有効化の順序

移行/起動条件の24件の単体テストはtransport spyと純粋policyを使い、SDKを初期化せず実行します。実施結果はPR本文に記録します。実SDK接続・実購入・実復元・期限切れ/返金・通知・家族共有は未実施です。

1. Dottoからapp/bundle/catalog、本人によるIAP鍵設定、public SDK key、privacyとrestore/transfer/通知を確認します。
2. Debugのみopt-inし、既購入の維持、購入/復元、解約/期限切れ、返金、家族共有、オフライン、SKU不足、再インストールを検証します。PlanOnceのローカル30日プレビューは購入扱いにせず、Peyoの旧removeAds購入者も確認します。
3. 結果を確認後、各アプリへ同じ手順を展開します。Release有効化・PR merge・公開/審査提出は別途扱います。

公式資料: [StoreKitとの併用](https://www.revenuecat.com/docs/migrating-to-revenuecat/sdk-or-not/finishing-transactions)、[既存購入の移行](https://www.revenuecat.com/docs/migrating-to-revenuecat/migrating-existing-subscriptions)、[Apple Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)。

## 今回の有効化準備

現在の公開・提出版を読み直した独立worktreeで準備しています。
公開ポリシーとASC申告の整合、連絡窓口、実接続の前提が揃うまではprivacyReadyをNOにします。
Dottoで購入・復元・返金・競合の検証手順を確立し、このアプリの全商品と既購入権へ展開します。
サブスク商品では期限切れ・更新・解約も確かめます。家族共有は対象商品の実設定に従います。
管理画面の登録・認証成功だけで、このアプリの購入や復元が利用可能とは判定しません。
merge・公開・提出・production切替は未実施です。

実接続の候補には`RevenueCatSandbox`を使います。既存のローカルStoreKit fixtureを指定しないschemeです。
通常のローカルStoreKitテストと、Apple SandboxからRevenueCatへの実接続を区別します。
