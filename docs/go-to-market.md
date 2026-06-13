# Go-to-Market 戦略

前提: ターゲットは Marvin 難民(英語圏の heavy reader)。彼らは「探している側」であり、
広告で需要を作る必要がない。見つけてもらう導線を正しく張ることがすべて。

## 1. ポジショニング

**「The Marvin successor」と名指しする。**一般 EPUB リーダーとして戦わない。

- 検索クエリは既に存在する: "Marvin alternative iOS" / "Marvin 3 replacement"。
  この indexed demand を ASO(App Store キーワード)と LP で取りに行く
- 訴求コピーの軸(customer-pains.md P2 × P8): **"Your highlights are yours."**
  - One-time purchase. No subscription.
  - Export highlights & notes to Markdown anytime.
  - Plain EPUB files. No proprietary library.
- 競合との対比軸: Apple Books(エクスポート不可)/ Kindle(自炊 EPUB 不可)/
  BookFusion(年 $100 サブスク)/ KOReader(iOS では導入困難)

### MarginNote との関係(競合ではなく隣接市場)

- MarginNote 3/4 は「教材を解体して勉強する」study tool(マインドマップ・
  フラッシュカード)。本アプリは「本を快適に読む」reading-first で、ジョブが違う。
  MarginNote で小説を読む人はほぼいない
- MarginNote の成功(買い切り $10+)は「注釈に金を払う市場がある」ことの証明
- 「MarginNote は重すぎた」離脱層はこちらのターゲット
- **機能競争はしない**。注釈機能の絶対量で MarginNote に勝てないため、
  「読み心地 × データの所有権」に絞る。比較されたら「勉強なら MarginNote、
  読書ならこちら」と認める方が信頼を得る

### 期待値(正直に)

ニッチ商品。大ヒットはしない。Marvin 難民 + PKM 層 + サブスク疲れ層で
月数十〜数百本が現実的なライン。「副業として小さく確実に回る商品」がゴール。

## 2. 価格

- **無料 DL + 買い切り IAP($9.99)のフリーミアム**
  - Paid up front は CVR が低く、難民は「まず Marvin の代わりになるか試したい」
  - 無料/有料の境界線は [ADR-0005](adr/0005-buy-once-pricing-storekit.md) で確定。
    **「読む」体験(インポート・レンダリング・レイアウト設定・全文検索・辞書)は永久無料**。
    課金境界は**注釈ワークフロー**(無制限ハイライト + Markdown エクスポート + 読書統計)に置く
  - 無料枠ハイライトは 1 冊あたり 3 件まで(機能を体験させてから上限で買わせる定石)。
    描画品質を確かめてから買える試用導線にする(冊数ではなく注釈で線引きするのは
    「描画品質を見て納得して払う」Marvin 難民の動機と相性が良いため)
- サブスクはやらない(P8 の反発がターゲットの来店動機そのもの)
- 将来の大型機能(iCloud 同期など)は v2 の有料アップグレードか上位買い切りで回収

## 3. チャネル(優先順)

1. **MobileRead Forums – Marvin フォーラム**: 難民が今も雑談している場所。
   開発ログを 1 スレッド立て、TestFlight ベータ募集 → 最初の 50 人はここから。
   彼らは Marvin の全機能を知っており、最高の QA かつエバンジェリストになる
2. **TestFlight 公開ベータ**: フィードバックで「Marvin で使っていたのに無い機能」を
   ロードマップ化(docs/TODO.md に直結)
3. **Reddit**: r/ebooks, r/ereader, r/ipad。宣伝ではなく
   「Marvin が死んだので自分で作っている」開発ストーリーとして投稿
4. **Show HN / Product Hunt**: ローンチ時。ストーリー性(愛用アプリの死 → 自作)は
   HN と相性が良い
5. **PKM 界隈(Obsidian / Notion ユーザー)**: Markdown エクスポート →
   Obsidian 取り込みのワークフロー動画。PKM 系 YouTuber へのレビュー依頼。
   「読書ノートが自動で vault に入る」は第二の顧客層を開く
6. **App Store Search Ads**: "marvin reader" "epub reader" の 2 ワードだけ少額で

## 4. ローンチ順序

1. TestFlight ベータ(MobileRead で募集)→ 2-3 週間
2. クラッシュ・致命的フィードバック対応
3. App Store 申請(素材: 2 カラム iPad スクショ / ハイライト→Obsidian 動画 / 統計画面)
4. 公開と同時に Show HN + Reddit + MobileRead に報告
5. 初週レビュー依頼はベータ参加者へ(初期レーティングがその後の ASO を決める)

## 5. 申請前に必要な非コード作業

- [ ] Apple Developer Program 登録
- [ ] プライバシーポリシーページ(データは端末内のみ = 強い訴求点。
  "No account. No tracking. No cloud." をポリシー自体がマーケになる形で)
- [ ] サポートページ(GitHub Issues でも可)
- [ ] App 名の最終決定(現: EPUB Reader。"Marvin" は商標リスクがあるため
  アプリ名には使わず、ASO キーワードと LP 文言で拾う)
- [ ] App Store スクリーンショット(英語、iPhone / iPad 両方)

## 6. 指標

- ベータ: MobileRead スレッドの参加数 / TestFlight 継続率
- ローンチ後: DL → 4 冊目到達率(課金トリガー)→ 購入 CVR / D7 リテンション
- 定性: 「Marvin から移行できた / できなかった理由」を全件記録 → TODO.md へ

## リスクと対応

- **市場が小さい**: Marvin 難民はニッチ。→ PKM 層(チャネル 5)と
  「サブスク疲れした読書家」(P8)で外周を広げる
- **Readium の制約**(ページめくりアニメ等 Marvin 比で欠ける UX)→
  ベータで「無いと移行できない機能」を特定してから作る。先回りしない
- **App 名・商標**: "Marvin" をアプリ名・スクショに使わない
