import SwiftUI
import Inject

struct SettingsView: View {
    @ObserveInjection var inject
    
    // 各セクションの項目を定義
    private let soundSettings = ["再生速度", "テンポ"]
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
            // TODO: 遷移先ページの実装（サンプル実装）
            .navigationDestination(for: String.self) { name in
                Text(name)
                    .font(.title2)
                    .navigationTitle(name)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}
