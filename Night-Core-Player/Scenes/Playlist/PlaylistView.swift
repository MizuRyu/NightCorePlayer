import SwiftUI
import Inject

struct PlaylistView: View {
    @ObserveInjection var inject
    @StateObject private var vm = PlaylistViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.categories) { cat in
                    VStack(spacing: 0) {
                        NavigationLink(value: cat) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.indigo)
                                    .frame(width: 24)
                                
                                Text(cat.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                        // 下線のみ描画
                        Divider()
                            .padding(.leading, 36)
                    }
                    // セル自体の罫線は非表示
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            // List全体の左余白にも背景色が乗らないように
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("プレイリスト")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}

