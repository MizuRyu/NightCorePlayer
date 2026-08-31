# 1.2 サイクル リファクタリング計画 (#69, #102, #103, #104)

> Status: In Progress
> Date: 2026-08-31
> 対象: 1.1 審査待ち期間〜1.2 リリースまで

1.1 提出後の改善サイクルの実行計画。個別 issue の背景は各 issue を、
残高設計の意図は [ADR-003](../adr/003-allowance-design.md) を参照。

## 実施順序と、その理由

進捗(2026-08-31 時点): #104 完了(PR #117)、Stage A 完了(PR #118)、Stage B1 完了(PR #119)、
Stage B2 レビュー中(PR #120)。残りは Stage C。

| 順 | 対象 | 内容 | なぜこの順か |
|---|---|---|---|
| 1 | #104 | 枯渇時の非モーダルバナー | Features 層のみで完結し他と競合しない。実機検証で2回指摘された体験問題を最小コストで解消 |
| 2 | #69 Stage A | Domain の SPM 切り出し | #102/#103 の解法は消費ロジックの作り替えを伴う。先に高速な `swift test` 基盤を作った方が、作り替えの検証コストが下がる |
| 3 | #69 Stage B | MusicKit/SwiftData の port 化 + contract テスト | Stage C で「プレイヤーの再生位置」を Domain から参照するために port が必要 |
| 4 | #69 Stage C = #102/#103 | 消費ロジック刷新 + 観測可能なスナップショット | 新構造の上で解決する。旧構造の上に実装すると Stage A/B で二度書きになる |
| 後続 | #68, #70, #71 | 計測導入・開発環境整備 | リファクタと独立。1.2 スコープに入れるかは別途判断 |

## 各項目の設計裁定

### #104: 非モーダルバナー(採用)

issue 提案どおりバナーを採用する。理由:

- ADR-003 の意図(BGM のブツ切り回避)は正しいが、「黙って猶予」は残高表示との矛盾に見える。
  伝えるべきは状態変化の予告であり、操作を要求しないのでモーダルは過剰
- 消滅条件はイベント駆動(`.stoppedAtSongEnd` / `.revertedToNormalRate` / タップ / 明示 dismiss)。
  タイムアウト消滅は「見逃したら結局無通知」なので採らない
- 新規 ViewModel は作らず `AllowanceSheetViewModel` に載せる。枯渇まわりの状態機械を
  1箇所に集約しておく方が Stage C の作り替えで移しやすい

### #69: 3段階に分割する

一括移行を避ける理由: テスト移行・型の公開範囲変更・Xcode プロジェクト設定が絡み、
1 PR で入れると codex レビューが実質不能になる。各 Stage を独立 PR にする。

- **Stage A — NightCoreDomain パッケージ新設**
  - Foundation のみに依存する純ロジックを `Packages/NightCoreDomain/` へ移す
  - 対象ファイルは依存棚卸し(下記)で確定
  - アプリターゲットは SPM 依存として取り込み、既存の型名・呼び出し側は変えない(まず移動のみ)
  - 受け入れ条件: `swift test --package-path Packages/NightCoreDomain` が simulator なしで通る
- **Stage B — port contract**(実施時に B1/B2 の 2 PR に分割した)
  - B1(PR #119): Repository 3 種の port contract 体制。同一の契約検証関数を in-memory fake と
    SwiftData 実実装の両方に適用し、`make test` と CI のゲートに SPM テストを追加
  - B2(PR #120): QueueManaging / PlayHistoryManaging を primary associated type で
    ジェネリック化して Domain へ移設。アプリ側は `Song` で特殊化
  - **RecommendationService の Domain 化は 1.2 では見送り**: 本体が MusicKitClient への
    取得依存であり、配合ロジックの純粋部分だけを切り出しても保守面の利得が薄い。
    必要になったら Song 抽象化(DomainSong 導入)とセットで再検討する
- **Stage C — 消費ロジック刷新(#102/#103 の本修正)**
  - #102: wall-clock 差分ではなく「曲 ID + 再生位置の差分」で消費量を計測する。
    再生位置が復元できない場合はクランプで誤魔化さず倍速を停止する(安全側)。
    既存テスト `tickClampsLongGapToSixtySeconds` は仕様変更として書き換える
  - #103: `AllowanceService` が表示用スナップショットを観測可能(@Observable)に保持し、
    consume / リワード付与 / 日次リセットの全経路で更新する。
    `SettingsViewModel.allowanceRevision` の回避策を撤去する
  - #104 の codex レビュー(PR #117)で見送った「日次リセット跨ぎで枯渇バナーが残留する」件も
    ここで解決する。バナーの表示可否をスナップショット(残高 > 0 か)から導出すれば、
    リセット経路ごとの個別イベント通知が不要になるため

### #102 を即修正しない理由(記録)

バックグラウンド再生 + 0.5s tick の現構成では 60 秒クランプに実運用で到達しにくく、
実害は限定的。一方で解法(再生位置ベース計測)は Enforcer の作り替えを伴うため、
旧構造への実装は Stage A/B との二度書きになる。よって Stage C に束ねる。

## 進め方の体制

- 実装はすべて指示書ベースでサブエージェント(impl 系)へ委譲。指示書には
  背景 / ゴール / 確定設計 / 触ってよい範囲 / チェック可能な完了条件 / 検証方法を書く
- 各 PR に codex の敵対的レビューを挟み、指摘は裁定のうえ修正 or issue 化して記録する
- マージは squash merge。main 直 push はしない
- 1.1 審査で修正差し戻しが来た場合はそちらを最優先し、本計画の PR は main へ入れたままで
  問題ない(1.1 のバイナリは build 10 で固定済みのため)

## Stage A 対象ファイル(依存棚卸し結果・2026-08-31 実測)

`Packages/NightCoreDomain/` へ移すもの(Foundation のみで完結、または機械的修正のみ):

| ファイル | 修正の要否 |
|---|---|
| `Models/Allowance.swift` / `History.swift` / `PlayerState.swift` | 無修正 |
| `Core/AppError.swift` | 無修正(Package に `defaultLocalization` とローカライズリソースが必要) |
| `Core/BusinessConstants.swift` + `LocalizationKeys.swift` | `artworkSize: CGFloat` が唯一の SwiftUI 依存 → CoreGraphics 化 or 数値型化 |
| `Services/AllowanceService.swift` | 無修正(外部依存は `AllowanceRepository` の init 1箇所のみ → Stage A で protocol port 化) |
| `Services/AllowanceEnforcer.swift` | 無修正(依存は `AllowanceService` protocol + クロージャのみ。既に理想的な port 形) |
| `Services/PlaybackRateManager.swift` | `PlayerStateRepository` 具象依存 → protocol port 化 |
| テスト: `AllowanceEnforcerTests` はそのまま移設。`AllowanceServiceTests` / `PlaybackRateManagerTests` は Repository fake 化で移設 | |
| fake: `Mock/AllowanceServiceMock.swift` / `Mock/RewardedAdServiceMock.swift` | Foundation のみ。パッケージ側 fake として移設可 |

移さないもの(Infrastructure 確定): SwiftData Repository 実装 / MPMusicPlayerAdapter /
MusicPlayerServiceImpl(769行・8依存のハブ、最終段まで触らない)/ 各 SDK 直依存 Service。

Stage B 以降の実測メモ:

- Repository 3種の公開シグネチャに SwiftData 型は漏れていない → port 化は容易。
  `PlayerStateRepository` のデフォルト値だけ `MPMusicShuffleMode` を参照しており数値化が要る
- Service→Service は全て protocol 経由で循環なし。composition root は `App.swift` に集約済み。
  port 未定義なのは Service→Repository の4辺のみで、ここが SwiftData 切り離しの唯一のボトルネック
- Song 抽象化(`DomainSong` 導入)は `makeDummySong` に依存する8テストが書き換えになる。
  移行コスト最大の塊なので Stage B の中でも後半に分離する
  (順: PlayHistoryManager → MusicQueueManager → RecommendationService)
- `RewardedAdService` の protocol は framework 型の漏れゼロで即 Domain 化可。
  `ProStoreService`(StoreKit `Product` 漏れ)と `TrackingAuthorizationService`(ATT enum 漏れ)は
  値型置換が必要
- SwiftData 統合テストの in-memory ModelContainer 化(#69 チェック項目)は `TestDataStore` で
  実現済み。ただしプロセス共有シングルトンのため状態リークに注意
