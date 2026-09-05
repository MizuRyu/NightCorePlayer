---
paths:
  - "**/Allowance*.swift"
  - "**/ProStore*.swift"
  - "**/RewardedAd*.swift"
---

# monetization — 残高 / 課金の落とせない制約

設計の全体像・状態遷移図は `docs/specs/ARCHITECTURE.md`（Monetization の内部分担）と
[ADR 003](../../docs/adr/003-allowance-design.md) を参照。ここは実装時に壊すと
規約違反・審査リジェクトに直結する制約だけを書く。

- **MUST** 残高ゲート（消費・枯渇判定）は **Nightcore 変換時（`playbackRate != 1.0`）にのみ**
  適用する。Apple Music の等速再生を制限してはいけない（MusicKit 利用規約上、
  等速再生を課金対象にできない）
- **MUST** リワード広告が出せない場合（ロード失敗・在庫切れ・表示失敗・SDK 未設定）は
  **エラーとして扱わず無条件で報酬を付与する**。ユーザーの落ち度ではない失敗をブロックに
  変えない（`RewardedAdServiceImpl` / `AllowanceSheetViewModel.watchAdForReward` 参照）
- **MUST** Pro 訴求（`showProPromptPitch`）は**生涯1回**。`markProPromptShown` の**保存が
  成功した場合のみ**訴求を表示する（保存失敗時に訴求だけ出すと「生涯1回」の保証が破れる）
- **MUST** 時刻の巻き戻り対策として `guardedNow = max(now, lastSeenAt)` を使う。
  端末時計を過去に戻す操作で残高が復活してはいけない
- **NEVER** Pro 権限の正典を `UserDefaults` に置かない（StoreKit のトランザクション履歴が正典。
  semgrep の `sensitive-data-in-userdefaults` が検出する）
