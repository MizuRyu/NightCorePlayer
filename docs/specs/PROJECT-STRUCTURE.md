# NightCorePlayer ディレクトリ構造

> 最終更新: 2026-03-23

プロジェクト全体のディレクトリ構成。各ディレクトリの責務は [ARCHITECTURE.md](./ARCHITECTURE.md) を参照。

---

## プロジェクトルート

```
NightCorePlayer/
├── Night-Core-Player/                   # アプリ本体ソース
├── Night-Core-PlayerTests/              # テスト
├── Night-Core-Player.xcodeproj/         # Xcode プロジェクト
├── docs/                                # ドキュメント
├── .claude/                             # Claude Code 設定
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
│   └── History.swift
│
├── Services/                            # Protocol + 具象 Service
│   ├── MusicPlayerService.swift         # Protocol群 + Snapshot
│   ├── MusicPlayerServiceImpl.swift     # 再生制御の具象
│   ├── MPMusicPlayerAdapter.swift       # MediaPlayer ラッパー
│   ├── MusicQueueManager.swift          # キュー論理操作
│   ├── PlayHistoryManager.swift         # 再生履歴管理
│   ├── MusicKitService.swift            # Apple Music 検索
│   ├── ArtworkCacheService.swift        # アートワークキャッシュ
│   ├── PlaybackRateManager.swift        # 再生速度設定
│   └── PlayerPersistenceService.swift   # 状態永続化
│
├── Data/                                # 永続化
│   ├── AppDataStore.swift               # ModelContainer 管理
│   ├── Entities/                        # SwiftData @Model
│   │   ├── PlayerStateEntity.swift
│   │   └── HistoryEntity.swift
│   └── Repositories/                    # Entity CRUD
│       ├── PlayerStateRepository.swift
│       └── HistoryRepository.swift
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
│   └── Settings/                        # 設定画面
│       ├── SettingsView.swift
│       ├── SettingsPlaybackSpeedView.swift
│       ├── SettingsViewModel.swift
│       └── TermsView.swift
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

## テスト (`Night-Core-PlayerTests/`)

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
│   └── Settings/
│       └── SettingsViewModelTests.swift
├── Services/                            # Service テスト
│   ├── MusicKitServiceTests.swift
│   ├── MusicPlayerServiceTests.swift
│   ├── PlaybackRateManagerTests.swift
│   ├── PlayerPersistenceServiceTests.swift
│   └── PlayHistoryManagerTests.swift
├── Mock/                                # テスト用 Mock
│   ├── MusicKitClientMock.swift
│   ├── MusicKitServiceMock.swift
│   └── MusicPlayerServiceMock.swift
└── Helpers/                             # テストヘルパー
    └── makeDummyData.swift
```

---

## ドキュメント (`docs/`)

```
docs/
├── specs/                               # 正式な仕様書
│   ├── ARCHITECTURE.md                  # アーキテクチャガイド
│   ├── TESTING-STRATEGY.md              # テスト方針
│   ├── PROJECT-RULES.md                 # 運用ルール
│   └── PROJECT-STRUCTURE.md             # 本ドキュメント
├── research/                            # 技術調査（参考資料）
│   └── swift-architecture-and-design-patterns.md
└── task/                                # タスク壁打ち
    ├── README.md
    ├── task00_アプリアイコン作成/
    ├── task01/
    ├── task02_検索履歴/
    └── task03_アプリリリースまでやること/
```
