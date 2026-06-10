# EPUB Reader (working title)

パワーユーザー向け・買い切り EPUB リーダー。開発放棄された Marvin の難民市場を対象にする。

## ゴール(第1マイルストーン)

**MVP を App Store に出し、Apple Developer Program のライセンス料 $99 を初月で回収する。**

- 価格: $9.99 買い切り(サブスクなし)
- 手取り: 約 $8.49/本(Small Business Program、Apple 取り分 15%)
- 回収ライン: **初月 12 本**
- 出口チャネル: MobileRead フォーラム(Marvin 難民スレ)、r/iosapps、r/ebooks

## 需要の根拠(2026-06 調査)

- Marvin 開発放棄(2023)から 3 年経っても「代替が無い」発言が継続
  - 「I've been obsessively trying to find a replacement for Marvin」(2024-05, Loopy Pro forum)
  - 「I don't mind paying for a really good full-featured ereader app」(MobileRead)
- 競合(Yomu / MapleRead / BookFusion / Cantook)はユーザー自身が不満を列挙: カスタマイズ不足、年 $100 サブスクへの反発、2 カラム表示不可
- 詳細は lockstep-ios リポジトリの調査ログ(2026-06-10 セッション)を参照

## MVP スコープ(これだけで $9.99 の価値を出す)

1. EPUB を Files から取り込み(ライブラリ画面)
2. 高品質なレンダリングとページめくり(Readium Swift)
3. フォント・テーマ・行間のカスタマイズ
4. ハイライト + メモ + 一括エクスポート(Marvin 難民の最重要要求)

### スコープ外(v1.1 以降)

- calibre / OPDS 連携
- 2 カラム表示(iPad)
- TTS 読み上げ
- 統計・読書ログ

## Day 0 spike(いまここ)

**仮説検証: Readium Swift toolkit で複雑な EPUB を快適にレンダリングできるか。**

- [ ] Readium 依存でビルドが通る
- [ ] 実機で EPUB を開いて読める(Files から import)
- [ ] CSS の複雑な EPUB(技術書・図表入り)で崩れないか確認
- [ ] ページめくり・目次ジャンプの体感速度
- [ ] ハイライト API(Decorator API)の存在確認

spike が通らなければ、レンダリングエンジン自作のコストを見積もってから Go/No-Go を再判断する(Lockstep の教訓: 核機能の実現可能性を Day 0 に検証する)。

## 動かし方

```bash
cd EPUBReaderSpike 2>/dev/null || true
xcodegen generate   # project.yml から .xcodeproj を生成
open EPUBReaderSpike.xcodeproj
```

Xcode で Signing の Team を選び、実機を選んで ▶。
