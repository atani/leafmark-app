# RevenueCatの段階導入（1.20から有効）

RevenueCat 5.92.0を既存StoreKitと併用する実装です。StoreKitが購入・finish・購入復元・利用権の正本です。RevenueCatのCustomerInfoからProを付与/削除しません。商品ID・価格・無料枠・家族共有の判定を維持しています。

## 状態

1.20（build 29）から、Release版でobserverとして起動します。`project.yml`はmode=observer、Leafmark (App Store) アプリの公開SDKキー、4ゲートすべてYESです。公開SDKキーはクライアントに埋め込む前提の公開キーで、秘密鍵ではありません。公開ポリシー（`privacy.html`と`docs/privacy-policy.md`）も、1.20から有効という内容に更新しました。

1.18〜1.19はSDKを無効のまま同梱していました。

## 基点と商品

GitHubの`main`（`ef72b89e2a1b1a741654098170d9b1c450d5849b`）を基点にしています。
商品ID: `"com.atani.inkwell.pro"`。

## 起動条件

各設定はbuild時にInfo.plistへ反映します。`Config/RevenueCatObserver.xcconfig.example`は設定項目の説明用で、プロジェクトには適用されません。

- `REVENUECAT_DATA_SHARING_APPROVED`: SDKが自動取得する過去・継続のproduction/Sandbox購入履歴と匿名ID等の送信承認です。
- `REVENUECAT_INTEGRATION_READY`: app/bundle/public SDK keyとApple IAP認証の確認です。既存全商品とrestore/transfer/通知設定も含みます。
- `REVENUECAT_PRIVACY_READY`: 実装と公開ポリシー/ASC申告の一致確認です。
- `REVENUECAT_RELEASE_ENABLED`: Release版で起動させる確認です。Debugでの接続には不要です。

これらに加えmode=observer、`appl_`で始まる公開キーと一致bundleが必要です。キーが空なら起動しません。テスト/Preview/demo/他bundleでは起動しません。Debugビルドは、キーとゲートがそろっていれば`REVENUECAT_RELEASE_ENABLED`に関係なく起動します。アプリのフィルタはSDK内部のTransaction.all/updates送信を制限しません。

SDKは.myApp/.storeKit2で構成し、独自appUserIDや氏名/email/広告属性は追加しません。device identifierの自動収集を無効にし、購入情報を含むSDKログ出力を抑制します。既存SDKインスタンスの流用を拒否します。OFF設定はbuild時の起動防止です。起動済みSDKの停止機能ではありません。停止にはOFFビルドへの更新と再起動が必要です。

## 移行と障害

手動同期候補は検証済み・未返金・有効期限内の既存商品です。同期商品集合を顧客ID別のv2 namespaceへ保存し、集合の増加時は再同期します。購入時は保存成功を無効化し、世代番号が変わった古い応答を捨てます。失敗/カタログ不足を成功として保存しません。同時実行を抑制し、次回起動/明示復元で再試行できます。これはSDK自身の自動履歴送信を限定するものではありません。通信失敗でも既存StoreKitによる購入成功や利用権を変えません。

## 検証と有効化の順序

移行/起動条件の単体テストはtransport spyと純粋policyを使い、SDKを初期化せず実行します。実施結果はPR本文に記録します。実SDK接続・実購入・実復元・期限切れ/返金・通知・家族共有は未実施です。

1. 済: app/bundle/catalog、IAP鍵設定、public SDK keyを用意しました。
2. 1.20のTestFlightで、既購入の維持、購入/復元、家族共有、オフライン、再インストールを確かめます。RevenueCatダッシュボードで既存購入者が同期されたかを見ます。
3. 結果を確認してから審査に提出します。PR merge・公開/審査提出は別途扱います。

公式資料: [StoreKitとの併用](https://www.revenuecat.com/docs/migrating-to-revenuecat/sdk-or-not/finishing-transactions)、[既存購入の移行](https://www.revenuecat.com/docs/migrating-to-revenuecat/migrating-existing-subscriptions)、[Apple Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)。
