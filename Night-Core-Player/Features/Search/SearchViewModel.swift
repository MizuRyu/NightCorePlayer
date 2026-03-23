import SwiftUI
import MusicKit
import Observation

@Observable
@MainActor
final class SearchViewModel {
    
    private let musicKitService: MusicKitService
    
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var songs: [Song] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery: String = ""
    
    init(musicKitService: MusicKitService) {
        self.musicKitService = musicKitService
    }
    
    private func scheduleSearch() {
        let current = query
        guard current != lastSearchedQuery else { return }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.searchDebounce) * 1_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(keyword: current)
        }
    }
    
    public func performSearch(keyword: String) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSearchedQuery = query
        guard !trimmed.isEmpty else { songs = []; return }
        
        isLoading = true; errorMessage = nil
        do {
            songs = try await musicKitService.searchSongs(keyword: trimmed, limit: Constants.MusicAPI.musicKitSearchLimit)
        } catch {
            self.errorMessage = error.localizedDescription; songs = []
        }
        isLoading = false
    }
}
