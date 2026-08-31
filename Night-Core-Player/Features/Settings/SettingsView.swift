import SwiftUI
import StoreKit
import Combine
import Inject
import NightCoreDomain

struct SettingsView: View {
    @ObserveInjection var inject
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(AllowanceSheetViewModel.self) private var allowanceSheetVM

    private enum SoundItem: String, CaseIterable, Hashable {
        case playbackSpeed

        var title: LocalizedStringKey {
            switch self {
            case .playbackSpeed: return "Playback Speed"
            }
        }
    }

    private enum OtherItem: String, CaseIterable, Hashable {
        case terms, feedback, review

        var title: LocalizedStringKey {
            switch self {
            case .terms: return "Terms & Privacy Policy"
            case .feedback: return "Feedback & Contact"
            case .review: return "Write a Review"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SoundItem.allCases, id: \.self) { item in
                        VStack(spacing: 0) {
                            NavigationLink(value: item) {
                                HStack {
                                    Text(item.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            }
                            Divider()
                                .padding(.leading, 16)
                        }
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Sound Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }

                allowanceSection

                proSection

                #if DEBUG
                    debugSection
                #endif

                Section {
                    ForEach(OtherItem.allCases, id: \.self) { item in
                        VStack(spacing: 0) {
                            otherRow(item)
                            Divider()
                                .padding(.leading, 16)
                        }
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Other")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Constants.UI.FrameSize.miniMusicPlayerContentInset, for: .scrollContent)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
            .navigationDestination(for: SoundItem.self) { item in
                switch item {
                case .playbackSpeed:
                    SettingsPlaybackSpeedView(settingsVM: settingsVM)
                        .navigationTitle("Sound Settings")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .task {
                settingsVM.refreshAllowance()
                await settingsVM.loadProState()
            }
            // 倍速再生中に残高が減っていくのを見せる。画面を離れれば task ごと止まる
            .task {
                for await _ in Timer.publish(every: 1, on: .main, in: .common).autoconnect().values {
                    settingsVM.refreshAllowance()
                }
            }
            // リワード付与は枠超過シート側で起きるため、閉じた時点で残高表示を追随させる
            .onChange(of: allowanceSheetVM.isPresented) { _, isPresented in
                if !isPresented { settingsVM.refreshAllowance() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 同一ViewへのalertはSwiftUIが片方しか表示しないため、エラーと通知を1つに統合する
        .alert(alertTitle, isPresented: Binding<Bool>(
            get: { alertMessage != nil },
            set: { if !$0 { dismissAlert() } }
        )) {
            Button("OK") { dismissAlert() }
        } message: {
            Text(alertMessage ?? "")
        }
        .enableInjection()
    }

    #if DEBUG
        // MARK: - Debug

        /// 残高の状態を手で作るための検証用セクション。トライアル中は枠超過シートに到達できず
        /// リワード広告を実機確認できないため置いている
        private var debugSection: some View {
            Section {
                debugRow("残高を使い切る（トライアル終了）") { settingsVM.debugExhaustAllowance() }
                debugRow("残高の記録を消す") { settingsVM.debugResetAllowance() }
                // 枠超過シートは曲が終わったときにだけ出るため、広告確認のために直接開く口を用意する
                debugRow("枠超過シートを開く") { allowanceSheetVM.debugPresent() }
            } header: {
                Text(verbatim: "デバッグ（Debug ビルドのみ）")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
        }

        /// 開発者だけが見る行のため、ローカライズせず日本語のまま出す
        private func debugRow(_ title: String, action: @escaping () -> Void) -> some View {
            VStack(spacing: 0) {
                Button(action: action) {
                    HStack {
                        Text(verbatim: title)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                    .padding(.leading, 16)
            }
            .listRowSeparator(.hidden)
        }
    #endif

    // MARK: - Alert

    private var alertMessage: String? {
        settingsVM.errorMessage ?? settingsVM.infoMessage
    }

    private var alertTitle: LocalizedStringKey {
        settingsVM.errorMessage != nil ? "Error" : "Pro"
    }

    private func dismissAlert() {
        settingsVM.errorMessage = nil
        settingsVM.infoMessage = nil
    }

    // MARK: - Allowance

    private var allowanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Today's Remaining Playback Time")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(settingsVM.remainingTimeText)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                // 制限が倍速再生だけに掛かることと、次に何が起きるかは画面上で分からないため補う
                Text(settingsVM.allowanceDetailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .accessibilityIdentifier("allowance_remaining_row")
            .listRowSeparator(.hidden)

            if !settingsVM.isProEntitled {
                // 従来は枠超過ダイアログからしか時間を増やせず、能動的に増やす導線がなかった
                VStack(spacing: 0) {
                    Button {
                        allowanceSheetVM.presentForAddingTime()
                    } label: {
                        HStack {
                            Text("Add Playback Time")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    Divider()
                        .padding(.leading, 16)
                }
                .listRowSeparator(.hidden)
            }
        } header: {
            Text("Playback Time")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)
        }
    }

    // MARK: - Pro

    @ViewBuilder
    private var proSection: some View {
        Section {
            if settingsVM.isProEntitled {
                HStack {
                    Text("Pro Active")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
                .padding(.vertical, 12)
                .listRowSeparator(.hidden)
            } else {
                purchaseRow
                restoreRow
            }
        } header: {
            Text("Pro")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)
        }
    }

    private var purchaseRow: some View {
        VStack(spacing: 0) {
            Button {
                settingsVM.purchasePro()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Pro")
                            .font(.body)
                            .foregroundColor(.primary)
                        Text("Unlimited playback time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if settingsVM.isPurchasing {
                        ProgressView()
                    } else if let price = settingsVM.proPriceText {
                        Text(price)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 12)
            }
            .disabled(settingsVM.isPurchasing)
            Divider()
                .padding(.leading, 16)
        }
        .listRowSeparator(.hidden)
    }

    private var restoreRow: some View {
        VStack(spacing: 0) {
            Button {
                settingsVM.restorePro()
            } label: {
                HStack {
                    Text("Restore Purchases")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .disabled(settingsVM.isPurchasing)
            Divider()
                .padding(.leading, 16)
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func otherRow(_ item: OtherItem) -> some View {
        switch item {
        case .review:
            // requestReview() は表示するかを OS が決め、年間の上限もあるため押しても何も起きないことがある。
            // ユーザーが自分で押した以上は必ずレビュー画面へ送る
            Link(destination: reviewURL) {
                rowLabel(item.title)
            }
        case .feedback:
            Link(destination: contactFormURL) {
                rowLabel(item.title)
            }
        case .terms:
            Link(destination: termsURL) {
                rowLabel(item.title)
            }
        }
    }

    private func rowLabel(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var contactFormURL: URL {
        URL(string: "https://forms.gle/p5CTaqH4omaJiEFx6")!
    }

    /// App Store のレビュー投稿画面を直接開く
    private var reviewURL: URL {
        URL(string: "https://apps.apple.com/app/id6761187661?action=write-review")!
    }

    private var termsURL: URL {
        URL(string: "https://mizuryu.github.io/NightCorePlayer/terms/")!
    }
}
