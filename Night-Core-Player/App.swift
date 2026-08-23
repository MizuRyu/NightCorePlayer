//
//  App.swift
//  Night-Core-Player
//
//  Created by RyuichiroMizutani on 2025/05/09.
//

import SwiftUI

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

    init() {
        #if DEBUG
            #if targetEnvironment(simulator)
            Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
            #endif
        #endif

        let navigator = PlayerNavigator()
        _nav = State(initialValue: navigator)

        // シミュレータは FairPlay 非対応のため、-DEMO 時のみ MusicKit カタログ系をスタブへ差し替える
        // （ensureAuth を no-op にすることで MusicAuthorization.request() も迂回する）
        let musicKitService: any MusicKitService
        if ProcessInfo.processInfo.arguments.contains("-DEMO") {
            musicKitService = DemoMusicKitService()
        } else {
            musicKitService = MusicKitServiceImpl()
        }

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
            playerNavigator: navigator
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
    }
}
