import SwiftUI
import MusicKit

@MainActor
class SearchViewModel: ObservableObject {
    
    @Published var searchText: String = ""
    @Published var filteredSongs: [Song] = []
    private var allTracks: [Track] = []
    @Published var filteredTracks: [Track] = []
    private var searchTask: Task<Void, Never>?
    
    func updateFilter() {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else {
            filteredSongs = []
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            do {
                let songs = try await MusicKitService.searchSongs(
                    keyword: key,
                    limit: 25
                )
                filteredSongs = songs
            } catch {
                print("Music Search Error:", error)
                filteredSongs = []
            }
        }
    }
}
