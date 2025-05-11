import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    private let baseTracks: [Track] = [
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
    
    @Published var searchText: String = ""
    private var allTracks: [Track] = []
    @Published var filteredTracks: [Track] = []
    
    init() {
        for i in 0..<10 {
            allTracks.append(baseTracks[i % baseTracks.count])
        }
        filteredTracks = allTracks
    }
    
    func updateFilter() {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty {
            filteredTracks = allTracks
        } else {
            filteredTracks = allTracks.filter {
                $0.title.lowercased().contains(key) ||
                $0.artist.lowercased().contains(key)
            }
        }
    }
}
