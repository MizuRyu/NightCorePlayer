# NightCorePlayer アーキテクチャガイド

> 最終更新: 2026-08-23

---

## アーキテクチャ概要

**MVVM + Service Layer（Protocol-based DI）**

50ファイル規模の個人開発プロジェクトとして、過剰設計を避けたシンプルな構成。Clean Architecture や DDD の用語・レイヤー名は使わない。UseCase 層や DI コンテナも導入しない。

```
┌──────────────────────────────────────────────────────┐
│ Features/     View + ViewModel (MVVM)                 │
│               UI の表示とユーザー操作の処理             │
├──────────────────────────────────────────────────────┤
│ Services/     Protocol + 具象 Service                  │
│               ビジネスロジック + 外部接続の調停層        │
├──────────────────────────────────────────────────────┤
│ Data/         永続化（SwiftData, Repository）          │
├──────────────────────────────────────────────────────┤
│ Core/         AppError, Constants                     │
│ Share/        共有 UI コンポーネント, ユーティリティ     │
│ Models/       共有データ型（どこからでも参照可能）       │
└──────────────────────────────────────────────────────┘
```

- `Features` → `Services` → `Data` の順に依存する
- `Models/` と `Core/` は共有基盤。どのディレクトリからも参照可能

---

## ディレクトリ構造

```
Night-Core-Player/
├── App.swift                              # Composition Root（全依存をここで構築）
│
├── Core/                                  # アプリ共通の基盤
│   ├── AppError.swift                     # 統一エラー型
│   ├── BusinessConstants.swift            # API制限, タイミング, 再生速度範囲
│   ├── UIConstants.swift                  # UI寸法, カラー
│   └── LocalizationKeys.swift             # 文字列定数
│
├── Models/                                # 純粋 struct（データ構造体）
│   ├── PlayerState.swift
│   └── History.swift
│
├── Services/                              # Protocol + 具象（同居）
│   │                                      #
│   │                                      # --- Playback（再生制御 + キュー + 履歴）---
│   ├── MusicPlayerService.swift           # Protocol群 + MusicPlayerSnapshot（※Impl は別ファイル）
│   ├── MusicPlayerServiceImpl.swift       # 再生制御の具象（544行超のため分離）
│   ├── MPMusicPlayerAdapter.swift         # MediaPlayer ラッパー
│   ├── MusicQueueManager.swift            # キュー論理操作
│   ├── PlayHistoryManager.swift           # Protocol + Impl 同居
│   │                                      #
│   │                                      # --- Catalog（曲の検索 + メタデータ）---
│   ├── MusicKitService.swift              # Protocol + Client + Impl + EnvironmentKey 同居
│   ├── ArtworkCacheService.swift          # Protocol + Impl 同居
│   │                                      #
│   │                                      # --- Preference（ユーザー設定）---
│   ├── PlaybackRateManager.swift          # Protocol + Impl 同居
│   │                                      #
│   │                                      # --- Persistence（横断: 状態の保存/復元）---
│   ├── PlayerPersistenceService.swift     # Protocol + Impl 同居
│   │                                      #
│   │                                      # --- Monetization（残高 + Pro 購入）---
│   ├── AllowanceService.swift             # 残高の状態遷移（Protocol + Impl 同居）
│   ├── AllowanceEnforcer.swift            # 再生tickでの消費 + 曲境界停止（Protocol + Impl 同居）
│   └── ProStoreService.swift              # StoreKit 2 Pro 購入（Protocol + Impl 同居）
│
├── Data/                                  # 永続化専用
│   ├── AppDataStore.swift                 # ModelContainer 管理
│   ├── Entities/                          # SwiftData @Model
│   │   ├── PlayerStateEntity.swift
│   │   └── HistoryEntity.swift
│   └── Repositories/                      # Entity の CRUD
│       ├── PlayerStateRepository.swift
│       └── HistoryRepository.swift
│
├── Features/                              # 機能単位（View + ViewModel）
│   ├── Common/
│   │   ├── MainTabView.swift
│   │   ├── MiniMusicPlayerView.swift
│   │   ├── PlayerNavigator.swift          # タブ遷移の状態管理
│   │   ├── SongRowView.swift
│   │   └── PlayingQueueItemRowView.swift
│   ├── MusicPlayer/
│   │   ├── MusicPlayerView.swift
│   │   ├── MusicPlayerViewModel.swift
│   │   └── PlayingQueueView.swift
│   ├── Playlist/
│   │   ├── PlaylistView.swift
│   │   ├── PlaylistDetailView.swift
│   │   ├── PlaylistViewModel.swift
│   │   ├── PlaylistDetailViewModel.swift
│   │   └── PlaylistRowModel.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── SettingsPlaybackSpeedView.swift
│   │   ├── SettingsViewModel.swift
│   │   └── TermsView.swift
│   └── Allowance/
│       ├── AllowanceSheetView.swift
│       └── AllowanceSheetViewModel.swift
│
├── Extensions/
│   └── Song+CatalogIdentifier.swift
│
└── Share/
    ├── Components/
    │   ├── MarqueeText.swift
    │   └── SongContextMenu.swift
    └── Utilities/
        ├── KeyboardResponder.swift
        └── timeStringFormat.swift
```

### 各ディレクトリの責務

| ディレクトリ | 何を置くか | 何を置かないか |
|-------------|-----------|--------------|
| `Core/` | エラー型、定数、アプリ全体で共有する基盤 | ビジネスロジック、UI コンポーネント |
| `Models/` | 純粋な Swift struct。値の形だけを持つ共有データ型 | `@Model` (SwiftData)、ビジネスロジック |
| `Services/` | Protocol + 具象。ビジネスロジックと外部接続を持つ調停層 | View、ViewModel |
| `Data/` | SwiftData Entity、Repository、ModelContainer 管理 | ビジネスロジック |
| `Features/` | View + ViewModel。機能単位でグルーピング | Service、Repository |
| `Extensions/` | 既存型の拡張 | 新しい型の定義 |
| `Share/` | 複数 Feature で共有する UI コンポーネント、ユーティリティ | ビジネスロジック |

**Models/ について:** `Models/` は層ではなく、複数ディレクトリから参照される共有データ型の置き場。`PlayerState` や `History` は Service と Repository の間でデータをやり取りするための形を定義しているだけで、振る舞い（メソッド）は持たない。「モデル中心設計」ではなく「Service 中心設計」であり、Models はその入出力の型。

**Services/ について:** `Services/` はこのアプリのビジネスロジックと外部接続がすべて入る場所。放っておくと何でも箱になりやすいため、**ファイルを追加するときは必ず以下のどのコンテキストに属するかを意識する**：

| コンテキスト | 責務 | 既存 Service |
|-------------|------|-------------|
| **Playback** | 再生制御 + キュー + セッション速度 + 履歴 | `MusicPlayerService*`, `MusicQueueManager`, `MPMusicPlayerAdapter`, `PlayHistoryManager` |
| **Catalog** | Apple Music 検索 + アートワーク取得 | `MusicKitService`, `ArtworkCacheService` |
| **Preference** | ユーザー設定（デフォルト速度） | `PlaybackRateManager` |
| **Persistence** | 状態の保存/復元（横断的関心事） | `PlayerPersistenceService` |
| **Monetization** | 残高（トライアル/無料枠/リワード）の状態遷移 + 再生への適用 + Pro 購入 | `AllowanceService`, `AllowanceEnforcer`, `ProStoreService` |

新しい Service を追加する場合は、どのコンテキストに属するかをファイル先頭のコメントに明記すること。既存のどのコンテキストにも属さない場合は、新しいコンテキストを定義するか、設計を見直すシグナルとして扱う。

**Service の分割トリガー:**
- 1つの Service が複数コンテキストを跨いでいる → コンテキストごとに分割
- I/O 調停（API 呼び出し、DB 操作）とビジネス判断（バリデーション、状態遷移）が混在している → 調停と判断を分離
- ファイルが 300 行を超えた → 責務を見直して分割を検討

---

## ドメインコンテキスト

アプリの概念を3つのコンテキスト + 横断的関心事に分ける。

コンテキストはディレクトリ構造には直接反映しない。コードを読む際の「この Service はどの関心事に属するか」の判断基準として使う。

| コンテキスト | 何をするか | 該当 Service |
|-------------|-----------|-------------|
| **Catalog** | 曲を見つける。Apple Music カタログとの対話。アートワーク取得 | `MusicKitService`, `ArtworkCacheService` |
| **Playback** | 曲を聴く。再生制御 + キュー管理 + セッション速度。再生ログ | `MusicPlayerService`, `PlayHistoryManager` |
| **Preference** | 好みを決める。デフォルト速度の管理 | `PlaybackRateManager` |
| **Persistence**（横断） | 前回の状態を覚えておく | `PlayerPersistenceService`, Repositories |
| **Monetization** | Nightcore 再生の残高を管理し、枯渇時に再生を止める。Pro 購入 | `AllowanceService`, `AllowanceEnforcer`, `ProStoreService` |

### Monetization の内部分担

`AllowanceService` と `AllowanceEnforcer` は「状態」と「適用」で責務を分けている。

| Service | 役割 | 永続化 |
|---------|------|--------|
| `AllowanceService` | `AllowanceSnapshot`（残高・トライアル終了日・リワード回数等）の読み書きと、日次リセット・トライアル判定などの状態遷移 | する（`AllowanceRepository` 経由で SwiftData） |
| `AllowanceEnforcer` | `MusicPlayerServiceImpl` の再生 tick から呼ばれ、倍速再生時のみ経過時間を `AllowanceService.consume` に渡す。残高が尽きたら即停止せず、その時点で鳴っていた曲が終わるまで再生を続けたうえで停止する（曲境界停止）。猶予は残高が回復するまで1曲ぶんで、使い切ったあとの倍速は曲末を待たず等速へ戻す | しない（メモリ上の状態のみ） |
| `ProStoreService` | StoreKit 2 で Pro（非消耗型 `MizuRyu.NightCorePlayer.pro`）を購入・復元し、`isProEntitled` を公開する。Pro ユーザーは `AllowanceEnforcer` の消費・停止の対象外 | StoreKit のトランザクション履歴に委譲 |

**設計上の制約:** 残高ゲートは Nightcore 変換（`playbackRate != 1.0`）にのみ掛ける。Apple Music の素の等速再生は制限しない（MusicKit 利用規約上、等速再生を課金対象にできないため）。時計を過去に戻す操作への対策として `guardedNow = max(now, lastSeenAt)` を使い、残高の巻き戻りを防いでいる。背景は [ADR 003](../adr/003-allowance-design.md) を参照。

### イベントフロー（枯渇 → シート表示）

```
MusicPlayerServiceImpl.tick()
        │ isPlaying, rate, songID, now
        ▼
AllowanceEnforcer.tick()
        │ consume() → AllowanceService（残高更新）
        │ 残高0 かつ 倍速再生中
        │   ├ 猶予が未使用 → graceSongID = songID（その曲だけ曲末まで許可）
        │   └ 猶予を使用済み → needsRevertToNormalRate = true
        ▼
        ├─ .exhaustedPendingSongEnd（猶予の開始。現状は購読者なし）
        │
        ├─ 曲境界到達 → shouldStopAtSongBoundary() → 再生停止 + markStoppedAtSongEnd()
        └─ 猶予切れで倍速 → shouldRevertToNormalRateNow() → 等速へ戻す + markRevertedToNormalRate()
                                    │ .stoppedAtSongEnd
                                    ▼
                          AllowanceSheetViewModel（購読）
                                    ▼
                          AllowanceSheetView（+30分 / Pro購入 / 閉じる）
```

### 「速度」は2つの意味を持つ

| 概念 | 定義 | Owner | 永続化 |
|------|------|-------|--------|
| Session Rate | 今の再生に適用されている速度 | `MusicPlayerService` | しない |
| Default Rate | ユーザーの好み。起動時に適用 | `PlaybackRateManager` | する |

Player 画面は Session Rate を操作し、Settings 画面は Default Rate を操作する。

---

## 設計ルール

### 1. ディレクトリ間の関係

このプロジェクトは厳密なレイヤードアーキテクチャではない。ディレクトリは責務別の整理であり、上下関係ではなく**参照ルール**で管理する。

```
Features (View/VM)  ──→ Services を Protocol 経由で使う
                    ──→ Models を参照する

Services            ──→ Data (Repository) を使う
                    ──→ Models を参照する
                    ──→ Core (Constants, AppError) を参照する

Data (Repository)   ──→ Entities (SwiftData @Model) を操作する
                    ──→ Core を参照する

Models              ──→ Core を参照する（または依存なし）

Core                ──→ 他のディレクトリに依存しない
```

**Models は「層」ではなく「共有データ型」。** Features, Services, Data のどこからでも参照される。

- ViewModel は Service を Protocol 経由で使う
- Service は Repository を直接使う。ただし永続化に近い Service（`PlayerPersistenceService`, `PlaybackRateManager` 等）をテストで isolation したい場合は、Repository を Protocol 化して Mock 差し替えを許容する
- `MusicKit.Song` はアプリ全体で使用する共通型として全ディレクトリで許容

### 2. DI ルール

- **依存グラフは `App.swift`（Composition Root）で一箇所で構築する**
- ViewModel は `init` で Service を受け取る（Constructor Injection）
- View / ViewModel で具象クラスを直接生成しない（`= XXXImpl()` のデフォルト引数は禁止）
- DI コンテナ（Swinject 等）は使わない。この規模では過剰

### 3. エラーハンドリング

```
Repository:  throws で上位に伝搬（内部で握りつぶさない）
Service:     throws で上位に伝搬 + AppError に変換
ViewModel:   do-catch → errorMessage: String? に変換（最終 catch 地点）
View:        errorMessage の有無で .alert 表示（try/catch は書かない）
```

### 4. 状態管理

- ViewModel: `@Observable`（Observation framework）
- Service → ViewModel: Combine `snapshotPublisher`（MusicPlayerService のみ。将来 AsyncStream に移行可能）
- View ← ViewModel: `@Environment` で注入
- `@EnvironmentObject` は使わない

### 5. Protocol 設計

- 1 Protocol 1 責務（Interface Segregation Principle）
- **Protocol と具象は同じファイルに同居する。** `// MARK: - Protocol` と `// MARK: - Impl` で区切る。抽象と具象が近くにあった方が読みやすく、変更時の影響を把握しやすい
- 例外: `MusicPlayerService.swift`（Protocol群 110行）と `MusicPlayerServiceImpl.swift`（具象 434行）は合計 544行になるため分離維持
- テスト用 Mock は `Tests/Mock/` に配置

### 6. ファイル構成

- 1 ファイル 1 主要型（例外: Protocol + Impl の同居は許容）
- Feature 単位でグルーピング（Feature-first, Layer-second）
- 3階層以上のディレクトリネストを避ける
- コメントは日本語。`// MARK: -` でセクション区切り

---

## やらないこと

この規模では過剰設計になるため、以下は意図的に導入しない：

| パターン | 不採用の理由 |
|----------|------------|
| `Domain/` `Infrastructure/` 等の DDD / Clean Architecture レイヤー名 | 実態が伴わない名前は読む側の期待をずらす。MVVM + Service Layer の実態に合った名前を使う |
| UseCase / Interactor 層 | VM が直接 Service を呼ぶ形で十分。ビジネスロジックが複雑化したら検討 |
| DI コンテナ（Swinject, Factory 等） | Constructor Injection + Composition Root で十分 |
| SPM マルチモジュール | 単一ターゲットで十分。Widget Extension 追加時に検討 |
| CQRS / Event Sourcing | 50ファイル規模では明らかに過剰 |
| Domain Event 基盤 | Combine Publisher や単純なコールバックで十分 |
| Coordinator パターン | SwiftUI の NavigationStack で十分 |
| TCA | 個人開発の生産性に対してボイラープレートが多すぎる |

---

## データフロー

```
┌─ SearchView ←── SearchViewModel ←──── MusicKitService ──→ Apple Music API
│
├─ PlaylistView ←── PlaylistViewModel ←── MusicKitService
│   └─ PlaylistDetailView ←── PlaylistDetailViewModel
│                                  │
│                                  │ 曲を選んでキューに入れる
│                                  ▼
├─ MusicPlayerView ←─┐
│                     ├── MusicPlayerViewModel ←── MusicPlayerService
├─ MiniMusicPlayerView ←┘        │                    ↕
│                                │              MPMusicPlayerAdapter
├─ PlayingQueueView              │                    ↕
│                                │              MusicQueueManager
│                                ├──→ ArtworkCacheService ──→ Apple Music CDN
│                                ├──→ PlayHistoryManager ──→ HistoryRepository
│                                ├──→ PlayerPersistenceService ──→ PlayerStateRepository
│                                │                                    ↕
│                                │                                SwiftData
│                                └──→ AllowanceEnforcer ──→ AllowanceService ──→ AllowanceRepository
│                                              │                                    ↕
│                                              │                                SwiftData
│                                              │ events
│                                              ▼
├─ AllowanceSheetView ←── AllowanceSheetViewModel ──→ AllowanceService
│                                              └──→ ProStoreService ──→ StoreKit 2
│
└─ SettingsView ←── SettingsViewModel ←── PlaybackRateManager
                              │               │
                              │               └──→ PlayerStateRepository
                              ├──→ ProStoreService ──→ StoreKit 2
                              └──→ AllowanceService ──→ AllowanceRepository
```

---

## テスト方針

- 新規コードはテストファースト
- Mock は `Tests/Mock/` に集約
- ViewModel テストで UI テストを代替（UI テストは不要）
- Service テストは Protocol + Mock で外部依存を遮断
- Repository テストは SwiftData の in-memory container を使用

---

## 将来の拡張ポイント

規模が拡大した場合に検討するもの：

| トリガー | 対応 |
|----------|------|
| ビジネスロジックが複雑化 | UseCase 層の導入 |
| ファイル数が 100 を超えた | SPM マルチモジュール化 |
| Widget / Watch App を追加 | Services / Models を共有パッケージに抽出 |
| チーム開発に移行 | モジュール境界の `public` / `internal` 厳格化 |
| Swift 6 Strict Concurrency | `Sendable` 準拠、`any` / `some` の明示 |
