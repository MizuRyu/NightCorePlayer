import Foundation

@MainActor
class PlaylistDetailViewModel: ObservableObject {
    let category: PlaylistCategory
    @Published var tracks: [Track] = []
    
    init(category: PlaylistCategory) {
        self.category = category
        
        loadMockTracks()
    }
    
    private func loadMockTracks() {
        let base: [Track] = [
            .init(
                title: "title1",
                artist: "artist1",
                artworkName: "imgAssets1",
                fileURL: Bundle.main.url(forResource: "track1", withExtension: "mp4")!
            ),
            .init(
                title: "title2",
                artist: "artist2",
                artworkName: "imgAssets2",
                fileURL: Bundle.main.url(forResource: "track2", withExtension: "mp4")!
            )
        ]
        self.tracks = (0..<5).map { i in base[i % base.count] }
    }
}
