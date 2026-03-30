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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
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
