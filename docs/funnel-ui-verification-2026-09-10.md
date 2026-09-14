# 購入導線・書き出し UI 検証（2026-09-10）

## 確認環境

- iOS 26.5 Simulator / iPhone 17e
- iOS 26.5 Simulator / 専用 iPad mini (A17 Pro)「Leafmark UI Check iPad」
- 同梱 Frankenstein と検証専用の引用・日本語ノートを使用。実購入・ストア公開は行っていない。

## 実操作で確認済み

- iPhone: ハイライト0件の空表示と、上限前の Upgrade 文言。
- iPhone: 購入画面の読書ノート完成例と既存の買い切り表示。
- iPhone: ハイライト一覧の文字付き書き出しボタン、実データの Markdown プレビュー。
- iPhone: 共有シートを閉じると無料枠が維持され、再度共有できる。
- iPhone: Files の「このiPhone内」へ保存すると「Unlock Unlimited Export」に変わる。一覧でも「Unlimited export with Pro」に変わる。
- iPhone: Library メニューから Pro 画面へ遷移する。
- iPhone: 無料の Statistics に本人の Today「2m」と、有料履歴の案内が表示される。
- iPhone: ライト表示のプレビュー・購入案内、ダーク表示のプレビュー・一覧・共有シート・統計を確認。
- iPad: 通常文字サイズのプレビューは縦・横向きとも文章と書き出しボタンが表示される。
- iPad: 共有シートが表示され、閉じた後も無料書き出しボタンが残る。
- iPad: Files の「このiPad内」への保存完了後、「Unlock Unlimited Export」へ変わることを追加確認。
- iPad: 最大文字サイズでもアクセシビリティ経由で「Unlock Unlimited Export」を実行でき、無料枠使用済みの Pro 案内へ遷移する。
- iPhone の統計、iPad のプレビューで最大アクセシビリティ文字サイズの上部表示・折り返しを確認。設定値は `accessibility-extra-extra-extra-large` を読み取り確認。

## 検証で発見して修正した不具合

Files 保存後も無料枠が残るケースを再現した。共有成功の記録を SwiftUI の `onDismiss` から UIActivityViewController の成功コールバックへ移した。終了通知の順序に依存させない。

修正後、iPhoneでキャンセル時の維持と保存成功時の消費を再確認した。独立レビューも追加の具体的指摘なし。

## 自動検証

StoreManagerTests / StatsStoreTests / HighlightStoreTests（29件）のシミュレータテストが成功。修正後も同じ対象で再実行して成功。`git diff --check` も成功。

## 未確認の範囲

- 最大文字サイズで画面下部までスクロールしてボタンに到達する操作。自動操作ツールの scroll / drag が反映されず、到達を検証できなかった。追加で iPad のポインタキャプチャと Page Down も試したがスクロールは反映されなかった。アクセシビリティ経由でのボタン実行は確認済みだが、指でスクロールする操作の代替検証とはしない。
- VoiceOver の音声読み上げ順序、全要素のタッチ領域の実測。
- 実購入・復元、購入済み状態の実操作、全画面での外観・向き・文字サイズの全組合せ。

文字サイズは通常の large に戻し、iPhone はライト外観へ復元。追加確認後、iPad のポインタ・キーボードキャプチャもオフへ復元。専用 iPad と検証用サンプルデータは再確認用に残した。
