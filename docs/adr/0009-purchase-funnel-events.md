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

1. 計測は Firebase Analytics で行います。Peyo で運用実績があるためです。IDFA を扱わない `FirebaseAnalyticsCore` を使い、AdSupport は組み込みません。IDFV の収集、広告のパーソナライズ信号、広告ネットワークへの登録、画面の自動計測は Info.plist で止めます。`first_open` や `session_start` などの自動イベントは、流入の分母として残します。
2. 独自に送るイベントは次の 4 つだけです。名前とパラメータは固定の列挙値にし、書名や本文などの自由文字列は送りません。
   - `paywall_shown`（パラメータ `source`）
     - `export_limit`: 無料の書き出しを使い切った後に書き出そうとした
     - `settings`: ライブラリのメニューから Leafmark Pro を開いた
     - `bulk_export`: Pro 限定の一括書き出しを選んだ
     - `highlight_limit`: 1 冊 3 件の無料ハイライトを使い切った後にハイライトしようとした
     - `highlights_upgrade`: ハイライト一覧の無料プラン欄から「Upgrade」を押した
     - `statistics`: Pro 限定の読書統計を開こうとした
   - `free_export_used`
   - `purchase_tapped`
   - `purchase_completed`（StoreKit で検証済みの購入が確定したとき。復元は含めません）
3. 本を開いた、ページをめくった、ハイライトしたといった読書行動は送りません。
4. 送信は Release ビルドだけです。Debug、テスト、SwiftUI Preview、スクリーンショット用の起動では Firebase を構成しません。`GoogleService-Info.plist` が無いビルドも構成しません。
5. 1.20 で入れ、プライバシーポリシーと ASC のプライバシー申告を同じ版で更新します。2026-11-16 の改定より前に審査を通すことを目標にします。
6. RevenueCat は同じ 1.20 で observer として有効にします。手順と現状は `docs/revenuecat-migration.md` に書きます。

## Consequences

- 改定前と改定後で、ペイウォールの表示から購入への比率を比べられます。ASC の購入件数と組み合わせて判断します。
- 依存パッケージが増えます（Firebase Analytics と、その依存の GoogleAppMeasurement など）。
- ASC の申告に次の項目が加わります。どれもユーザーに紐づけず、トラッキングにも使いません。
  - 使用状況データ > 製品の操作（4 イベントと自動のセッションイベント）
  - 識別子 > デバイス ID（Firebase のアプリインスタンス ID）
  - 位置情報 > おおよその場所（マスクした IP から Google が推定する地域）
  - 購入 > 購入履歴（Firebase の購入計測と RevenueCat）
- 審査が 11/16 に間に合わなければ、改定前のデータは取れません。その場合は改定後のデータだけで判断します。
