//
//  App.swift
//  Night-Core-Player
//
//  Created by RyuichiroMizutani on 2025/05/09.
//

import SwiftUI
import GoogleMobileAds

@main
struct NightcorePlayerApp: App {
    @State private var nav: PlayerNavigator
    @State private var playerVM: MusicPlayerViewModel
    @State private var settingsVM: SettingsViewModel
    @State private var searchVM: SearchViewModel
    @State private var playlistVM: PlaylistViewModel
    @State private var keyboard = KeyboardResponder()
    @State private var allowanceSheetVM: AllowanceSheetViewModel
    private let playerService: MusicPlayerService
    private let isDemo: Bool
    private let trackingService: TrackingAuthorizationService
    private let rewardedAdService: RewardedAdService?

    init() {
        #if DEBUG
            #if targetEnvironment(simulator)
            Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
            #endif
        #endif

        let navigator = PlayerNavigator()
        _nav = State(initialValue: navigator)

        let isDemo = ProcessInfo.processInfo.arguments.contains("-DEMO")
        self.isDemo = isDemo
        trackingService = TrackingAuthorizationServiceImpl()

        // シミュレータは FairPlay 非対応のため、-DEMO 時のみ MusicKit カタログ系をスタブへ差し替える
        // （ensureAuth を no-op にすることで MusicAuthorization.request() も迂回する）
        let musicKitService: any MusicKitService
        if isDemo {
            musicKitService = DemoMusicKitService()
        } else {
            musicKitService = MusicKitServiceImpl()
        }

        // デモ録画に広告が出ると困るため、-DEMO 時はATT要求・SDK初期化とも行わない
        // 実際の要求とSDK初期化はメインUI表示後（mainRootView の .task）にまとめて行う
        let rewardedAdService: RewardedAdService?
        if isDemo {
            rewardedAdService = nil
        } else {
            rewardedAdService = RewardedAdServiceImpl()
        }
        self.rewardedAdService = rewardedAdService

        let context = AppDataStore.shared.container.mainContext
        let playerStateRepo = PlayerStateRepository(context: context)
        let historyRepo = HistoryRepository(context: context)

        let rateManager = PlaybackRateManagerImpl(repo: playerStateRepo)
        let persistenceService = PlayerPersistenceServiceImpl(
            playerStateRepo: playerStateRepo,
            historyRepo: historyRepo
        )
        let historyManager = PlayHistoryManagerImpl(historyRepo: historyRepo)
        let artworkService = ArtworkCacheServiceImpl()

        let allowanceService = AllowanceServiceImpl(
            repo: AllowanceRepository(context: context)
        )
        let proStoreService = ProStoreServiceImpl()
        let allowanceEnforcer = AllowanceEnforcerImpl(
            allowanceService: allowanceService,
            isProEntitled: { proStoreService.isProEntitled }
        )

        let service = MusicPlayerServiceImpl(
            rateManager: rateManager,
            persistenceService: persistenceService,
            historyManager: historyManager,
            artworkService: artworkService,
            musicKitService: musicKitService,
            allowanceEnforcer: allowanceEnforcer
        )

        playerService = service
        _playerVM = State(initialValue: MusicPlayerViewModel(service: service))
        _settingsVM = State(initialValue: SettingsViewModel(
            rateManager: rateManager,
            playerService: service,
            proStore: proStoreService,
            allowanceService: allowanceService
        ))
        _searchVM = State(initialValue: SearchViewModel(musicKitService: musicKitService))
        _playlistVM = State(initialValue: PlaylistViewModel(musicKitService: musicKitService))
        _allowanceSheetVM = State(initialValue: AllowanceSheetViewModel(
            allowanceEnforcer: allowanceEnforcer,
            allowanceService: allowanceService,
            proStoreService: proStoreService,
            playerNavigator: navigator,
            rewardedAdService: rewardedAdService
        ))
    }

    var body: some Scene {
        WindowGroup {
            appRootView
        }
    }

    @ViewBuilder
    private var appRootView: some View {
        #if DEBUG
            if let screenshotScene = AppStoreScreenshotScene.current {
                AppStoreScreenshotRootView(scene: screenshotScene)
            } else {
                mainRootView
            }
        #else
            mainRootView
        #endif
    }

    private var mainRootView: some View {
        MainTabView()
            .environment(nav)
            .environment(playerVM)
            .environment(settingsVM)
            .environment(searchVM)
            .environment(playlistVM)
            .environment(keyboard)
            .environment(allowanceSheetVM)
            .task {
                await playerService.start()
            }
            .task {
                await initializeAdsIfNeeded()
            }
    }

    /// ATT許可要求 → 完了待ち → SDK初期化 → 広告preload の順で行う。
    /// IDFAゼロ化を避けるため、要求前にSDKを初期化しない
    private func initializeAdsIfNeeded() async {
        guard !isDemo, let rewardedAdService else { return }
        await trackingService.requestIfNeeded()
        await MobileAds.shared.start()
        await rewardedAdService.preload()
    }
}
