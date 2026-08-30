# 審査ノート (App Review Notes)

App Store Connect の「App Review 情報 → メモ」に貼る本文と、その根拠をまとめる。
リワード広告と買い切り課金を併用する構成は、意図を書かないと機能未確認のまま差し戻されやすい。

## 提出時に貼る本文 (日本語)

```
【アプリの概要】
Apple Music のサブスクリプション契約者が、自分のライブラリやカタログの楽曲を
高速・高ピッチ (Nightcore スタイル) で再生するアプリです。
再生には Apple Music の有効なサブスクリプションが必要です。

【課金と広告の構成】
等速 (1.0倍) での再生は無料かつ無制限です。時間制限を設けているのは
倍速変換 (Nightcore 再生) のみで、Apple Music の通常再生は一切制限していません。

- 初回起動から 7 日間: 倍速再生も無制限 (トライアル)
- トライアル終了後: 1 日あたり 3600 秒の無料枠 (日次リセット、繰越なし)
- リワード広告の視聴で +1800 秒を追加 (任意)
- Pro (非消耗型、MizuRyu.NightCorePlayer.pro) の購入で無制限

リワード広告の視聴は任意です。広告を見ずに Pro を購入する選択肢を
同じダイアログ内に並べて提示しており、広告視聴を強制していません。

【審査時の確認手順 — 重要】
初回起動から 7 日間はトライアル期間のため倍速再生が無制限になり、
そのままでは課金・広告の画面に到達できません。ご確認には次の操作が必要です。

1. Apple Music にサインインした状態でアプリを起動する
2. 「検索」タブから任意の楽曲を再生する
3. プレイヤー画面の速度スライダーで 1.0 倍以外に変更する
4. トライアル終了後の状態を確認する場合は、
   1 日あたりの無料枠 3600 秒を消費するか、下記の審査用アカウントをご利用ください

【残高が尽きたときの挙動】
残高が 0 になっても再生中の曲は最後まで再生し、曲の切れ目で倍速再生のみを停止します
(音楽が途中で途切れることはありません)。停止と同時に、広告視聴と Pro 購入を
選べるダイアログを表示します。等速再生はその後も継続できます。

【トラッキングについて】
広告 (Google AdMob) のために ATT の許可を求めますが、許可しない場合でも
パーソナライズされない広告が配信され、アプリの全機能を利用できます。
```

## 提出時に貼る本文 (English)

```
[Overview]
This app plays songs from a user's Apple Music library or the Apple Music catalog
at increased speed and pitch (nightcore style). An active Apple Music subscription
is required for playback.

[Monetization]
Normal-speed (1.0x) playback is free and unlimited. The time limit applies only to
the sped-up (nightcore) conversion; standard Apple Music playback is never restricted.

- First 7 days after install: unlimited sped-up playback (trial)
- After the trial: 3600 seconds per day (resets daily, does not carry over)
- Watching a rewarded ad adds 1800 seconds (optional)
- Pro (non-consumable, MizuRyu.NightCorePlayer.pro) removes the limit

Watching the rewarded ad is optional. The Pro purchase is presented side by side
in the same dialog, so users are never required to watch an ad.

[How to reach the paywall — important]
During the first 7 days the trial grants unlimited sped-up playback, so the
purchase and ad screens cannot be reached without the following steps:

1. Launch the app while signed in to Apple Music
2. Play any song from the Search tab
3. Change the playback rate to something other than 1.0x using the speed slider
4. To see the post-trial state, either consume the 3600-second daily allowance
   or use the review account provided below

[Behavior when the allowance runs out]
When the allowance reaches zero, the app finishes the current track and stops only
the sped-up playback at the track boundary (audio is never cut off mid-song).
A dialog then offers a rewarded ad or the Pro purchase. Normal-speed playback continues.

[Tracking]
The app requests ATT permission for advertising (Google AdMob). Declining is fully
supported: non-personalized ads are served and all app features remain available.
```

## この内容にした理由

| 書いたこと | なぜ必要か |
|---|---|
| 等速再生は無制限 | MusicKit の利用条件上、素の再生を制限できない。制限しているのが変換部分だけであることを示さないと、Apple Music の機能を人質にした課金と誤解されうる |
| 広告視聴は任意で Pro と並置 | リワード広告を課金の唯一の回避手段にすると、広告視聴の強制と見なされる懸念がある |
| トライアル 7 日間で到達できない | **最大の差し戻し要因**。審査担当者が初回起動するとトライアル中で、課金画面に到達できない。手順を書かないと機能未確認で差し戻される |
| 曲末で停止する挙動 | 意図的な設計 (ADR-003) であり、不具合ではないことを示す |
| ATT を拒否しても全機能が使える | ATT の説明が不十分だと Guideline 5.1.2 で指摘されうる |

## 提出前チェックリスト

- [ ] App Store Connect のアプリ内課金 Pro で「審査用に追加」を実行済み
      (最初の非消耗型は、アプリのバージョンと同時に提出する必要がある)
- [ ] 課金の「審査に関する情報」にスクリーンショットを添付
      (`build/app-review/iap-pro-dialog.png`)
- [ ] サインイン可能な審査用アカウント、または Apple Music の契約状況について記載
- [ ] プライバシーポリシー URL が到達すること
      (https://mizuryu.github.io/NightCorePlayer/privacy/)
- [ ] サポート URL が到達すること
      (https://mizuryu.github.io/NightCorePlayer/support/)
- [ ] スクリーンショット 6.9 / 6.5 インチをアップロード済み

## 想定される差し戻しと対応

| 指摘 | 想定される理由 | 対応 |
|---|---|---|
| 課金の動作を確認できない | トライアル中で課金画面に到達できていない | 上記の確認手順を再送し、必要なら残高消費済みの審査用アカウントを提供する |
| Apple Music の機能を制限している | 等速再生も制限されていると誤解された | 制限対象が倍速変換のみである点を、該当コードの挙動とあわせて説明する |
| 広告視聴を強制している | 広告が唯一の回避手段だと見なされた | 同一ダイアログに Pro が並置されているスクリーンショットを提示する |
| ATT の説明が不足 | 5.1.2 | 拒否時も全機能が使えること、非パーソナライズ広告に切り替わることを説明する |
