import Combine
import SwiftUI
import MusicKit

@MainActor
class SearchViewModel: ObservableObject {
    
    @Published var query: String = ""
    @Published private(set) var songs: [Song] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = $query
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] keyword in
                Task { await self?.performSearch(keyword: keyword) }
            }
    }
    
    deinit { cancellable?.cancel() }
    
    public func performSearch(keyword: String) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { songs = []; return }
        
        isLoading = true; error = nil
        do {
            songs = try await MusicKitService.searchSongs(keyword: trimmed, limit: Constants.MusicAPI.musicKitSearchLimit)
        } catch {
            self.error = error; songs = []
        }
        isLoading = false
    }
}
