import SwiftUI
import StoreKit
import Inject

struct SettingsView: View {
    @ObserveInjection var inject
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.requestReview) private var requestReview

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
                await settingsVM.loadProState()
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
            HStack {
                Text("Today's Remaining Playback Time")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text(settingsVM.remainingTimeText)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .accessibilityIdentifier("allowance_remaining_row")
            .listRowSeparator(.hidden)
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
            Button {
                requestReview()
            } label: {
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

    private var termsURL: URL {
        URL(string: "https://mizuryu.github.io/NightCorePlayer/terms/")!
    }
}
