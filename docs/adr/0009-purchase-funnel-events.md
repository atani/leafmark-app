# ADR-0009: 購入までの 4 イベントだけを匿名で計測します

- Status: Accepted
- Date: 2026-10-23

## Context

初回 DL 188 件に対して Pro の購入は 8 件です（2026-06-27〜10-11、ASC 販売レポート）。どこで離脱しているかを測る手段がありません。

- RevenueCat の SDK は同梱していますが、`REVENUECAT_MODE: disabled` で動いていません。記録は 2026-10-17 以降のサーバー通知 1 件だけで、顧客は匿名 ID です。
- Firebase などの計測 SDK は入っていません。
- RevenueCat を有効にしても、得られるのは購入側のデータです。ペイウォールに来た人数は分かりません。

2026-11-16 に $14.99 へ改定します。改定後に購入が減ったとき、原因が価格かペイウォールへの到達数かを切り分けられません。

公開中のプライバシーポリシーは「読書行動の追跡と広告はしない」と約束しています。計測はこの約束の範囲に収める必要があります。

## Decision

1. 計測は Firebase Analytics で行います。Peyo で運用実績があるためです。
2. 広告に使える情報は集めません。「広告はしない」という約束を、設定でも守るためです。
   - IDFA を扱わない `FirebaseAnalyticsCore` を使い、AdSupport は組み込みません。`FirebaseAnalytics` は IDFA 対応のモジュールを同梱します。
   - Info.plist で、IDFV の収集、広告のパーソナライズ信号、広告用の保存と利用者データ、広告ネットワークへの登録を止めます。
   - 画面の自動計測も止めます。画面名から読書の様子が分かるのを避けるためです。
   - `first_open` や `session_start` などの自動イベントは、流入の分母として残します。
3. 独自に送るイベントは次の 4 つだけです。名前とパラメータは固定の列挙値にし、書名や本文などの自由文字列は送りません。
   - `paywall_shown`、`purchase_tapped`、`purchase_completed` には、入口を表す `source` を付けます。
     - `export_limit`: 無料の書き出しを使い切った後に書き出そうとした
     - `library_menu`: ライブラリのメニューから Leafmark Pro を開いた
     - `bulk_export`: Pro 限定の一括書き出しを選んだ
     - `highlight_limit`: 読書中に、1 冊 3 件の無料ハイライトを使い切った後でハイライトしようとした
     - `highlights_upgrade`: ハイライト一覧の無料プラン欄から「Upgrade」を押した
     - `statistics`: Pro 限定の読書統計を開こうとした
   - `free_export_used`: 1 回だけ無料の書き出しを使った
   - `purchase_tapped`: 購入ボタンを押した
   - `purchase_completed`: StoreKit で検証済みの新しい購入が確定した
     - Ask to Buy などで後から承認された購入も、その端末で始めた購入なら数えます。
     - 復元と、すでに Pro を持つ Apple ID の再購入は数えません。購入前に Pro だったか、取引の購入日が購入の開始より前かで判定します。Ask to Buy の承認では、保存した購入の開始時刻だけで判定します。
     - 家族共有で使えるようになった Pro も数えません。
4. 本を開いた、ページをめくった、ハイライトしたといった読書行動は送りません。
5. 送るのは、App Store の本番環境で動く Release ビルドだけです。
   - Debug、テスト、SwiftUI Preview、スクリーンショット用の起動では Firebase を構成しません。
   - `AppTransaction` の環境が本番でなければ送りません。TestFlight と審査は Sandbox で動くため、テスターや審査の購入が転換率に混ざりません。環境を取得できないときも送りません。
   - 環境は起動時に 1 回だけ確かめます。起動時に `AppTransaction` を取れなかったセッションは計測されません。
6. `GoogleService-Info.plist` はコミットしません。リポジトリが公開されており、API キーなどを含むためです。
   - Release ビルドのときだけ、手元にあれば同梱します。無ければビルドが警告を出し、Firebase を構成しません。
   - 取得方法は README に書きます。
7. 1.20 で入れ、プライバシーポリシーと ASC のプライバシー申告を同じ版で更新します。2026-11-16 の改定より前に審査を通すことを目標にします。
8. RevenueCat は同じ 1.20 で observer として有効にします。手順と現状は `docs/revenuecat-migration.md` に書きます。

## Consequences

- 改定前と改定後で、入口ごとにペイウォールの表示から購入への比率を比べられます。ASC の購入件数と組み合わせて判断します。
- 依存パッケージが増えます（Firebase Analytics と、その依存の GoogleAppMeasurement など）。
- ASC の申告に次の項目が加わります。どれもユーザーに紐づけず、トラッキングにも使いません。`Sources/PrivacyInfo.xcprivacy` と、同梱 SDK の privacy manifest も同じ内容です。
  - 使用状況データ > 製品の操作（4 イベントと自動のセッションイベント）。用途はアナリティクスです。
  - 識別子 > デバイス ID（Firebase のアプリインスタンス ID）。用途はアナリティクスです。
  - 位置情報 > おおよその場所（マスクした IP から Google が推定する地域）。用途はアナリティクスです。
  - 購入 > 購入履歴（Firebase の購入計測と RevenueCat）。用途はアナリティクスとアプリの機能です。
  - 診断 > その他の診断データ（FirebaseInstallations が自身の manifest で申告）。用途はアナリティクスです。
- 審査が 11/16 に間に合わなければ、改定前のデータは取れません。その場合は改定後のデータだけで判断します。
