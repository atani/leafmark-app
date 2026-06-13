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

## 未撮影(XcodeBuildMCP の UI 自動化で撮る)

`osascript` のピクセルタップはツールバーの小アイコンに精度が足りず、本文・設定・ハイライト画面まで
到達できなかった。残りは XcodeBuildMCP(`.mcp.json`)が有効な新セッションの UI 自動化で撮る。

- [ ] 本文ページ(Chapter I の冒頭。リフロー描画・日本語/英語タイポグラフィ)
- [ ] レイアウト設定パネル(AA。フォント・行間・余白・2カラム)
- [ ] ハイライト一覧 + Markdown エクスポートの共有シート
- [ ] 読書統計

## サイズ

最終的に App Store は 6.9"(1320×2868)基準。iPhone 17 Pro Max Simulator で撮り直すと
そのまま使える。iPhone 17(1206×2622)で撮ったものはプレビュー/構図確認用。
