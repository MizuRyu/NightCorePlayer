# NightCorePlayer ディレクトリ構造

> 最終更新: 2026-08-23

プロジェクト全体のディレクトリ構成。各ディレクトリの責務は [ARCHITECTURE.md](./ARCHITECTURE.md) を参照。

---

## プロジェクトルート

```
NightCorePlayer/
├── Night-Core-Player/                   # アプリ本体ソース
├── Night-Core-PlayerTests/              # ユニットテスト
├── Night-Core-PlayerUITests/            # デモ録画専用の UI テスト
├── Night-Core-Player.xcodeproj/         # Xcode プロジェクト
├── scripts/                             # デモ録画・カタログ生成・スクリーンショット生成
├── docs/                                # ドキュメント
├── .github/workflows/                   # CI・デモカタログ更新
├── fastlane/                            # App Store 提出の自動化
├── privacy-policy/                      # 利用規約・プライバシーポリシー（MkDocs）
├── .swiftlint.yml                       # SwiftLint 設定
├── .swiftformat                         # SwiftFormat 設定
├── lefthook.yml                         # pre-commit / commit-msg フック
├── Makefile                             # check / build / lint / test / format
├── Gemfile / Gemfile.lock               # fastlane 用 Ruby 依存
├── .gitignore
└── README.md
```

---

## アプリ本体 (`Night-Core-Player/`)

```
Night-Core-Player/
├── App.swift                            # Composition Root
│
├── Core/                                # アプリ共通基盤
│   ├── AppError.swift
│   ├── BusinessConstants.swift
│   ├── UIConstants.swift
│   └── LocalizationKeys.swift
│
├── Models/                              # 共有データ型（純粋 struct）
│   ├── PlayerState.swift
│   ├── History.swift
│   └── Allowance.swift                  # PlaybackEntitlement, AllowanceSnapshot
│
├── Services/                            # Protocol + 具象 Service
│   ├── MusicPlayerService.swift         # Protocol群 + Snapshot
│   ├── MusicPlayerServiceImpl.swift     # 再生制御の具象
│   ├── MPMusicPlayerAdapter.swift       # MediaPlayer ラッパー
│   ├── MusicQueueManager.swift          # キュー論理操作
│   ├── PlayHistoryManager.swift         # 再生履歴管理
│   ├── MusicKitService.swift            # Apple Music 検索
│   ├── DemoMusicKitService.swift        # -DEMO 起動時のみ使う MusicKit スタブ
│   ├── ArtworkCacheService.swift        # アートワークキャッシュ
│   ├── PlaybackRateManager.swift        # 再生速度設定
│   ├── PlayerPersistenceService.swift   # 状態永続化
│   ├── AllowanceService.swift           # 残高（トライアル/無料枠/リワード）の状態遷移
│   ├── AllowanceEnforcer.swift          # 再生tickでの残高消費 + 曲境界停止
│   └── ProStoreService.swift            # StoreKit 2 による Pro 購入
│
├── Data/                                # 永続化
│   ├── AppDataStore.swift               # ModelContainer 管理
│   ├── Entities/                        # SwiftData @Model
│   │   ├── PlayerStateEntity.swift
│   │   ├── HistoryEntity.swift
│   │   └── AllowanceEntity.swift        # 残高スナップショット（単一行）
│   └── Repositories/                    # Entity CRUD
│       ├── PlayerStateRepository.swift
│       ├── HistoryRepository.swift
│       └── AllowanceRepository.swift
│
├── Features/                            # 機能単位（View + ViewModel）
│   ├── Common/                          # 共通 UI（タブ、ミニプレーヤー等）
│   │   ├── MainTabView.swift
│   │   ├── MiniMusicPlayerView.swift
│   │   ├── PlayerNavigator.swift
│   │   ├── SongRowView.swift
│   │   └── PlayingQueueItemRowView.swift
│   ├── MusicPlayer/                     # プレーヤー画面
│   │   ├── MusicPlayerView.swift
│   │   ├── MusicPlayerViewModel.swift
│   │   └── PlayingQueueView.swift
│   ├── Playlist/                        # プレイリスト画面
│   │   ├── PlaylistView.swift
│   │   ├── PlaylistDetailView.swift
│   │   ├── PlaylistViewModel.swift
│   │   ├── PlaylistDetailViewModel.swift
│   │   └── PlaylistRowModel.swift
│   ├── Search/                          # 検索画面
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   ├── ArtistDetailView.swift
│   │   ├── ArtistDetailViewModel.swift
│   │   └── ArtistRowView.swift
│   ├── Settings/                        # 設定画面
│   │   ├── SettingsView.swift
│   │   ├── SettingsPlaybackSpeedView.swift
│   │   ├── SettingsViewModel.swift
│   │   └── TermsView.swift
│   ├── Allowance/                       # 残高枯渇シート（+30分 / Pro購入 / 閉じる）
│   │   ├── AllowanceSheetView.swift
│   │   └── AllowanceSheetViewModel.swift
│   └── AppStore/                        # App Store スクショ用ショーケース画面
│       └── AppStoreScreenshotMode.swift
│
├── Extensions/
│   └── Song+CatalogIdentifier.swift
│
└── Share/                               # 共有 UI・ユーティリティ
    ├── Components/
    │   ├── MarqueeText.swift
    │   └── SongContextMenu.swift
    └── Utilities/
        ├── KeyboardResponder.swift
        ├── ScrollDetector.swift
        └── timeStringFormat.swift
```

---

## ユニットテスト (`Night-Core-PlayerTests/`)

```
Night-Core-PlayerTests/
├── Features/                            # ViewModel テスト
│   ├── MusicPlayer/
│   │   └── MusicPlayerViewModelTests.swift
│   ├── Playlist/
│   │   ├── PlaylistDetailViewModelTests.swift
│   │   └── PlaylistViewModelTests.swift
│   ├── Search/
│   │   ├── ArtistDetailViewModelTests.swift
│   │   └── SearchViewModelTests.swift
│   ├── Settings/
│   │   └── SettingsViewModelTests.swift
│   └── Allowance/
│       └── AllowanceSheetViewModelTests.swift
├── Services/                            # Service テスト
│   ├── MusicKitServiceTests.swift
│   ├── MusicPlayerServiceTests.swift
│   ├── PlaybackRateManagerTests.swift
│   ├── PlayerPersistenceServiceTests.swift
│   ├── PlayHistoryManagerTests.swift
│   ├── AllowanceServiceTests.swift
│   └── AllowanceEnforcerTests.swift
├── Mock/                                # テスト用 Mock
│   ├── MusicKitClientMock.swift
│   ├── MusicKitServiceMock.swift
│   ├── MusicPlayerServiceMock.swift
│   ├── AllowanceServiceMock.swift
│   └── ProStoreServiceMock.swift
└── Helpers/                             # テストヘルパー
    └── makeDummyData.swift
```

`.swiftlint.yml` の nested configuration（`Night-Core-PlayerTests/.swiftlint.yml`）でテスト向けにルールを緩和している。詳細は [PROJECT-RULES.md](./PROJECT-RULES.md) を参照。

---

## デモ用 UI テスト (`Night-Core-PlayerUITests/`)

```
Night-Core-PlayerUITests/
└── DemoUITests.swift                    # testDemoScenario / testScreensCatalog
```

`scripts/record-demo.sh` から `-only-testing` で実行するデモ録画専用のテスト。`make test` / CI のユニットテストからは `-skip-testing:Night-Core-PlayerUITests` で除外している。

---

## デモ録画・カタログ生成 (`scripts/`)

```
scripts/
├── record-demo.sh                       # simctl 録画 + xcodebuild test + ffmpeg → GIF/mp4/スクショ/manifest.json/pr-body.md
├── build-demo-catalog.ts                # pr-assets/pr-<番号>/manifest.json → features/ へ昇格
└── capture_app_store_screenshots.sh     # App Store 用スクショの一括生成
```

`build-demo-catalog.ts` は `.github/workflows/demo-catalog.yml` から PR マージ時に実行される。詳細は [docs/conventions/pr-assets.md](../conventions/pr-assets.md) を参照。

---

## ドキュメント (`docs/`)

```
docs/
├── specs/                               # 正式な仕様書
│   ├── ARCHITECTURE.md                  # アーキテクチャガイド
│   ├── TESTING-STRATEGY.md              # テスト方針
│   ├── PROJECT-RULES.md                 # 運用ルール
│   ├── PROJECT-STRUCTURE.md             # 本ドキュメント
│   └── ASO-KEYWORDS.md                  # App Store 掲載メタデータ
├── adr/                                 # Architecture Decision Record
│   ├── 001-staged-queue-updates.md
│   ├── 002-no-pitch-independent-control.md
│   └── 003-allowance-design.md
├── conventions/                         # 運用規約の詳細
│   └── pr-assets.md                     # PR 成果物（スクショ・デモ動画）の置き場
├── research/                            # 技術調査（参考資料）
│   └── swift-architecture-and-design-patterns.md
├── memo/                                # 個人メモ（.gitignore 済み、コミット対象外）
└── task/                                # タスク壁打ち
    ├── README.md
    ├── task00_アプリアイコン作成/
    ├── task01/
    ├── task02_検索履歴/
    └── task03_アプリリリースまでやること/
```

---

## CI/CD (`.github/workflows/`)

```
.github/workflows/
├── ci.yml                               # PR/push 時のビルド + ユニットテスト
├── demo-catalog.yml                     # PR マージ時に pr-assets/features/ を更新
├── pages.yml                            # GitHub Pages（利用規約・プライバシーポリシー）デプロイ
└── release.yml                          # リリース関連
```
