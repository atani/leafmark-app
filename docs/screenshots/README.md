# App Store スクリーンショット素材

申請用スクリーンショットの撮影手順と現状。

## 撮影用の書籍

**Peter and Wendy(J. M. Barrie / Standard Ebooks)** を使う。パブリックドメインなので
表紙・本文を申請素材に使ってよい。手元の `Docker入門.epub`(技術評論社)は著作物なので使わない。

- 出典: Standard Ebooks(public domain dedication)
- ファイル: `tj4oyeckqgizr93cx14nz7mj-0026-peter-pan-j-m-barrie.epub`(リポジトリ root)

## 撮影手順(Simulator)

```bash
SIM=$(xcrun simctl list devices | grep "iPhone 17 " | grep -oE '[0-9A-F-]{36}' | head -1)
# クリーンなステータスバー(9:41・満充電・電波フル)
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
# 取り込み(Documents 直下に置くと起動時 scanInbox が拾う)
CONTAINER=$(xcrun simctl get_app_container $SIM com.atani.inkwell data)
cp peter-pan.epub "$CONTAINER/Documents/"
xcrun simctl launch $SIM com.atani.inkwell
xcrun simctl io $SIM screenshot 01-library.png
# 終わったら戻す
xcrun simctl status_bar $SIM clear
```

## 撮影済み

| ファイル | 内容 |
|---|---|
| `01-library.png` | ライブラリ。Peter and Wendy の表紙・書名・著者 |
| `02-reader-cover.png` | リーダーで表紙を全面レンダリング + ツールバー(検索/AA/ハイライト/目次) |
| `03-reader-text.png` | 本文ページ。Chapter I「Peter Breaks Through」のリフロー描画とセリフ体タイポグラフィ |
| `04-appearance.png` | レイアウト設定パネル(AA)。テーマ・フォント・文字サイズ・カラム数 |
| `05-paywall.png` | Leafmark Pro(買い切り訴求)。無制限ハイライト/エクスポート/統計、購入復元 |
| `06-highlights.png` | ハイライト一覧。4 色ハイライト + ノート + Markdown エクスポート |
| `07-statistics.png` | 読書統計。今日/週/累計の時間、連続 5 日、本ごとの時間 |
| `08-ipad-2column.png` | iPad Pro 13" の 2 カラム表示(`columnCount: 2`)。レイアウト検証用 |

XcodeBuildMCP(`.mcp.json`)の UI 自動化で撮影。`osascript` のピクセルタップでは届かなかった
ツールバーの小アイコンも、`snapshot_ui` の elementRef タップで正確に操作できた。

### 撮影上の注意

- ルート直下の 01〜08 は iPhone 17(1206×2622)/ iPad 13"(2064×2752)。プレビュー/構図確認用
- **App Store 提出用の最終セットは `6.9-inch/` に用意済み**(iPhone 17 Pro Max・1320×2868・英語)。下記参照
- 08 は iPad Pro 13"(2064×2752)。2 カラム表示の検証用。ランドスケープは MCP で回転を
  自動化できず縦向きで撮影、ステータスバーの日付がシステムロケールの日本語表示のため、
  英語版の最終 iPad スクショは手動で撮り直す(回転 + 英語ロケール)
- 05/06/07 は Pro 限定画面。MCP / `simctl launch` で起動したアプリには StoreKit 設定の商品が
  配信されない(購入ボタンが非活性)ため、DEBUG 限定の `-inkwellForcePro` launch 引数(`StoreManager`)で
  エンタイトルメントを解放して撮影した。リリースビルドには非搭載
- 06/07 のデータ(ハイライト 4 件・5 日分の読書セッション)はコンテナの `highlights.json` /
  `reading-sessions.json` にシードした。文面は J. M. Barrie の原文(パブリックドメイン)
- エクスポートの共有シートはシステム UI が日本語表示のため英語スクショには採用せず、`06` で
  エクスポート導線(ShareLink)を示すに留めた

## App Store 提出用セット(`6.9-inch/`)

iPhone 17 Pro Max(1320×2868 = 6.9" スロット・英語・9:41 ステータスバー)で撮影した提出用。
そのまま App Store Connect にアップロードできる。

| ファイル | 内容 |
|---|---|
| `01-library.png` | ライブラリ |
| `02-reader-cover.png` | 表紙の全面レンダリング |
| `03-reader-text.png` | 本文(Chapter I) |
| `04-appearance.png` | レイアウト設定 |
| `05-highlights.png` | ハイライト一覧 + エクスポート |
| `06-statistics.png` | 読書統計 |
| `07-paywall.png` | Leafmark Pro(買い切り) |

- 05/06 は `-inkwellForcePro` で Pro 解放、07 は非 Pro 起動で撮影(上の注意参照)。
- iPad ランドスケープ 2 カラムの提出用は未取得(MCP で回転を自動化できず)。手動で撮り直す。

## サイズ

最終的に App Store は 6.9"(1320×2868)基準。`6.9-inch/` がそのまま使える。
ルート直下の 01〜08(iPhone 17 = 1206×2622 / iPad = 2064×2752)はプレビュー/構図確認用。
