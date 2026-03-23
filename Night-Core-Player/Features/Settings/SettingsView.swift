import SwiftUI
import StoreKit
import Inject

struct SettingsView: View {
    @ObserveInjection var inject
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(\.requestReview) private var requestReview

    private let soundSettings = ["再生速度"]
    private let others = [
        "利用規約・プライバシーポリシー",
        "ご意見・お問い合わせ",
        "レビューを書く"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // ──────────── サウンド設定 ────────────
                Section {
                    ForEach(soundSettings, id: \.self) { name in
                        VStack(spacing: 0) {
                            NavigationLink(value: name) {
                                HStack {
                                    Text(name)
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
                    Text("サウンド設定")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
                
                // ──────────── その他 ────────────
                Section {
                    ForEach(others, id: \.self) { name in
                        VStack(spacing: 0) {
                            if name == "レビューを書く" {
                                Button {
                                    requestReview()
                                } label: {
                                    HStack {
                                        Text(name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                }
                            } else if name == "ご意見・お問い合わせ" {
                                Link(destination: contactMailURL) {
                                    HStack {
                                        Text(name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                }
                            } else {
                                NavigationLink(value: name) {
                                    HStack {
                                        Text(name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                }
                            }
                            Divider()
                                .padding(.leading, 16)
                        }
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("その他")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("設定")
            .navigationDestination(for: String.self) { name in
                switch name {
                case "再生速度":
                    SettingsPlaybackSpeedView(settingsVM: settingsVM)
                        .navigationTitle("サウンド設定")
                        .navigationBarTitleDisplayMode(.inline)
                case "利用規約・プライバシーポリシー":
                    TermsView()
                default:
                    Text(name)
                        .font(.title2)
                        .navigationTitle(name)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }

    /// お問い合わせ用メール URL
    private var contactMailURL: URL {
        let subject = "NightCore Player お問い合わせ"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:rmizutani.work@example.com?subject=\(encodedSubject)")!
    }
}
