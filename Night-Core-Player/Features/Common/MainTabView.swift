import SwiftUI
import Inject
import MusicKit
struct MainTabView: View {
    @ObserveInjection var inject
    @Environment(PlayerNavigator.self) private var nav
    @Environment(MusicPlayerViewModel.self) private var playerVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(KeyboardResponder.self) private var keyboard
    @Environment(AllowanceSheetViewModel.self) private var allowanceSheetVM

    private let miniPlayerHeight: CGFloat = Constants.UI.FrameSize.miniMusicPlayerHeight

    private var showMiniPlayer: Bool {
        nav.selectedTab != .player && !keyboard.isVisible
    }

    /// 枠超過の告知はタブ全体を覆うシートではなく中央のダイアログで出す
    private var allowanceDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { allowanceSheetVM.dismissByUser() }

            // Dynamic Type 最大や小画面ではカードが画面高を超えるため、はみ出したぶんだけスクロールさせる
            ScrollView(.vertical) {
                AllowanceSheetView(viewModel: allowanceSheetVM)
                    .frame(maxWidth: Constants.UI.FrameSize.dialogMaxWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(radius: 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(24)
        }
        .transition(.opacity)
        // 背後のタブや一覧へフォーカスが抜けないようにする
        .accessibilityAddTraits(.isModal)
    }

    var body: some View {
        @Bindable var nav = nav
        let tabBinding = Binding<PlayerNavigator.Tab>(
            get: { nav.selectedTab },
            set: { newTab in
                if newTab == nav.selectedTab && newTab == .search {
                    nav.searchBarFocusRequestID += 1
                }
                nav.selectedTab = newTab
            }
        )
        ZStack(alignment: .bottom) {
            TabView(selection: tabBinding) {
                MusicPlayerView()
                    .tabItem { Label("Player", systemImage: "music.note") }
                    .tag(PlayerNavigator.Tab.player)
                    .safeAreaPadding(.bottom, miniPlayerHeight)

                // 以下3タブの下端余白は各画面のList側(contentMargins)が持つ。
                // NavigationStack越しのsafeAreaPaddingは内部Listのスクロール余白に届かず、
                // ミニプレイヤーが最下行に被って操作できなくなるため
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(PlayerNavigator.Tab.search)

                PlaylistView()
                    .tabItem { Label("Playlist", systemImage: "list.bullet") }
                    .tag(PlayerNavigator.Tab.playlist)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(PlayerNavigator.Tab.settings)
            }
            .onScrollDetected { scrolling in
                nav.isScrolling = scrolling
            }
            .overlay(alignment: .bottom) {
                // 検索タブ位置にオーバーレイしてタップ/長押しを検出
                GeometryReader { geo in
                    let tabs = PlayerNavigator.Tab.allCases
                    let tabCount = max(1, CGFloat(tabs.count))
                    let tabWidth = geo.size.width / tabCount
                    let searchIndex = CGFloat(tabs.firstIndex(of: .search) ?? 1)
                    Color.clear
                        .frame(width: tabWidth, height: 50)
                        .contentShape(Rectangle())
                        .position(x: tabWidth * (searchIndex + 0.5), y: geo.size.height - 25)
                        .onTapGesture {
                            if nav.selectedTab == .search {
                                nav.searchBarFocusRequestID += 1
                            } else {
                                nav.selectedTab = .search
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            nav.selectedTab = .search
                            nav.searchBarFocusRequestID += 1
                        }
                }
            }

            if showMiniPlayer {
                MiniMusicPlayerView()
                    .frame(height: miniPlayerHeight)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            nav.selectedTab = .player
                        }
                    }
                    .padding(.bottom, Constants.UI.FrameSize.miniMusicPlayerBottomOffset)
                    .opacity(nav.isScrolling ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: nav.isScrolling)
            }
        }
        .overlay {
            if allowanceSheetVM.isPresented {
                allowanceDialog
            }
        }
        .animation(.easeInOut(duration: 0.2), value: allowanceSheetVM.isPresented)
        .enableInjection()
    }
}
