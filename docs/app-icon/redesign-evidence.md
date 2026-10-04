# Leafmark アプリアイコン再設計

## 結論

現行の「開いた本＋複数の文章線」から、「一枚の紙が葉と本の両方に見え、一本の黄色いハイライトが入る」アイコンへ変更します。読書・ハイライト・Leafmark という名前を、32pxでも残る一つのシルエットに集約します。

## 検討した3案

1. 紙の葉: 一枚の紙を葉／開いた本の形に折り、黄色いハイライトを一本だけ入れます。機能と名前を最少要素で結びつけられるため採用しました。
2. 蛍光ペンの葉: 葉の形をしたペン先で注釈機能を強調します。ただし、電子書籍リーダーより文具アプリに見えるリスクがあります。
3. ページのしおり: 折れたページ角をしおりの形にします。ただし、ハイライト／Markdown書き出しという差別化が伝わりにくいため見送りました。

## デザイン判断の根拠

- Appleは、アイコンがアプリの目的と個性を表し、一目で認識できることを重視しています。新案は文字や複数記号を使わず、紙の葉という単一モチーフに集約しています。
- Appleの現行仕様では、iOS／iPadOS用素材は1024×1024pxの正方形で用意し、角丸はシステム側が適用します。納品画像には角丸と外側の影を焼き込まず、1024×1024px・sRGB・不透明PNGにしています。
- AppleはApp Store Connectでアイコンを含む商品ページ要素のA/Bテストを提供し、ダウンロード転換率と相対リフトを測定しています。したがって「新案が必ずダウンロードを増やす」とは事前に断定せず、実際の効果はProduct Page Optimizationで検証します。
- 公開事例では、FoodNomsがアイコンのみのProduct Page Optimizationで推定ダウンロード転換率10%向上を報告しています。ただし単一アプリの事例であり、Leafmarkで同じ効果を保証する証拠ではありません。

## 実装・検証結果

- 基準アセット（旧版）: `Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Treatmentアセット（新案）: `Sources/Assets.xcassets/AppIconPaperLeaf.appiconset/icon-1024.png`
- 制作マスター: `docs/app-icon/leafmark-icon-master.png`
- 1024×1024px、sRGB、不透明PNGであることを確認しました。
- 64pxと32pxへ実際に縮小し、紙の葉／開いた本の輪郭と黄色い一本線を判別できることを目視確認しました。
- iOS Simulator向けのXcodeビルドが成功し、Asset Catalogへの組み込みを確認しました。
- 生成には組み込み画像生成を使用しました。角丸マスクは焼き込んでいません。

## リリース後の検証

旧アイコンをPrimaryの対照、新アイコン（asset name: `AppIconPaperLeaf`）をTreatmentとして、アイコン以外を変えないProduct Page Optimizationを実施します。Appleの判定に従い、90%以上の信頼度で「Performing Better」になった場合に勝ち案として採用します。

App Store Connectには、実験ID `386ebd9d-ae85-4967-99f6-fbebd93d2e4b`、名称「App Icon — Paper Leaf vs Original」、トラフィック50%でドラフトを作成済みです。Controlの流量をTreatment以上にするAppleの制約に合わせ、50%へ設定しました。v1.17 build 26は`READY_FOR_SALE`です。Treatment ID `3a88ff12-a3f5-4ea8-a48f-ce77220b0884`を登録し、実験専用Review Submission ID `96982ecf-6ea1-430d-aeb9-5ae890016ea9`を2026-09-19に提出しました。自動フォローアップ`leafmark-icon-a-b-rollout`が1時間ごとに状態を確認します。

## 出典

- Apple Human Interface Guidelines — App icons: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple App Store Connect Analytics — Product Page Optimization: https://developer.apple.com/help/app-store-connect-analytics/acquisition/product-page-optimization
- Apple App Store Connect Help — Configure test treatments: https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/configure-test-treatments
- FoodNoms — How FoodNoms' New App Icon Boosted Download Conversion Rate by 10%: https://foodnoms.com/news/new-foodnoms-app-icon
