import Foundation

struct PlaylistCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
}

@MainActor
class PlaylistViewModel: ObservableObject {
    @Published var categories: [PlaylistCategory] = [
        .init(name: "お気に入りの曲", iconName: "star.fill"),
        .init(name: "アーティスト", iconName: "mic.fill"),
        .init(name: "購入した音楽", iconName: "music.note"),
        .init(name: "プレイリスト１", iconName: "music.note.list"),
        .init(name: "プレイリスト２", iconName: "music.note.list")
    ]
}
