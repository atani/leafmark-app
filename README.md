# Leafmark

パワーユーザー向け・買い切り EPUB リーダー。開発放棄された Marvin の難民市場を対象にする。

**"Your highlights are yours."** — アカウントなし・トラッキングなし・クラウドなし。
ハイライトはいつでも Markdown でエクスポートできる。

## ゴール(第1マイルストーン)

**MVP を App Store に出し、Apple Developer Program のライセンス料 $99 を初月で回収する。**

- 価格: 無料 3 冊 + $9.99 買い切り IAP(サブスクなし)
- 手取り: 約 $8.49/本(Small Business Program、Apple 取り分 15%)
- 回収ライン: **初月 12 本**
- 出口チャネル: MobileRead フォーラム(Marvin 難民スレ)、r/iosapps、r/ebooks
- 詳細: [docs/go-to-market.md](docs/go-to-market.md)

## 実装済み(v0.3)

- ライブラリ: カバーグリッド / Files から複数インポート / Documents 自動取り込み / Open in
- リーダー: 目次ジャンプ / 進捗表示 / 読書位置の永続化(再起動後も復元)
- ハイライト 4 色 + ノート + **Markdown エクスポート**(Marvin 難民の最重要要求)
- 全文検索 / システム辞書ルックアップ
- 読書統計(日・週・累計 / streak / 本ごと)
- テーマ 3 種 / フォント 5 種 / サイズ / 行間 / 余白 / スクロールモード
- iPad ランドスケープ 2 カラム表示

## ドキュメント

- [顧客ペイン P1-P8](docs/customer-pains.md) / [ロードマップ](docs/TODO.md)
- [ADR](docs/adr/)(Readium 採用 / ファイルベース永続化 / Decorator API)
- [Go-to-Market](docs/go-to-market.md) / [ベータ募集草稿](docs/beta-announcement-mobileread.md)
- [Privacy Policy](docs/privacy-policy.md) / [Support](docs/support.md)(App Store 申請用)

## 動かし方

```bash
xcodegen generate   # project.yml から .xcodeproj を生成
open Inkwell.xcodeproj
```

Xcode で Signing の Team を選び、実機 or シミュレータで ▶。
テスト用 EPUB はアプリの Documents 直下に置けば起動時に自動取り込みされる。
