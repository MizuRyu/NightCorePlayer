import SwiftUI
import MusicKit
import Observation

@Observable
@MainActor
final class SearchViewModel {

    private let musicKitService: MusicKitService
    private let userDefaults: UserDefaults

    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var songs: [Song] = []
    private(set) var artists: [Artist] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMoreSongs = false
    var errorMessage: String?

    // MARK: - Search History

    private(set) var searchHistory: [String] = []
    private let historyKey = "searchHistory"
    private let maxHistoryCount = 20

    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery: String = ""
    private var currentOffset: Int = 0

    init(musicKitService: MusicKitService, userDefaults: UserDefaults = .standard) {
        self.musicKitService = musicKitService
        self.userDefaults = userDefaults
        self.searchHistory = userDefaults.stringArray(forKey: historyKey) ?? []
    }

    // MARK: - Search

    private func scheduleSearch() {
        let current = query
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空クエリは debounce せず即座にクリア → 履歴表示に切り替わる
        if trimmed.isEmpty {
            searchTask?.cancel()
            songs = []
            artists = []
            hasMoreSongs = false
            currentOffset = 0
            lastSearchedQuery = ""
            return
        }

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
        lastSearchedQuery = trimmed
        guard !trimmed.isEmpty else {
            songs = []
            artists = []
            hasMoreSongs = false
            currentOffset = 0
            return
        }

        isLoading = true; errorMessage = nil
        currentOffset = 0
        defer { isLoading = false }
        do {
            async let fetchedSongs = musicKitService.searchSongs(
                keyword: trimmed, limit: Constants.MusicAPI.musicKitSearchLimit, offset: 0
            )
            async let fetchedArtists = musicKitService.searchArtists(
                keyword: trimmed, limit: 5
            )
            songs = try await fetchedSongs
            artists = try await fetchedArtists
            currentOffset = songs.count
            hasMoreSongs = songs.count >= Constants.MusicAPI.musicKitSearchLimit
            saveToHistory(trimmed)
        } catch {
            if Task.isCancelled || error is CancellationError
                || (error as NSError).code == NSURLErrorCancelled {
                return
            }
            self.errorMessage = error.localizedDescription
            songs = []
            artists = []
            hasMoreSongs = false
        }
    }

    func loadMoreSongsIfNeeded(currentSong: Song) async {
        guard hasMoreSongs, !isLoadingMore,
              currentSong.id == songs.last?.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let trimmed = lastSearchedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let more = try await musicKitService.searchSongs(
                keyword: trimmed, limit: Constants.MusicAPI.musicKitSearchLimit, offset: currentOffset
            )
            songs.append(contentsOf: more)
            currentOffset += more.count
            hasMoreSongs = more.count >= Constants.MusicAPI.musicKitSearchLimit
        } catch {}
    }

    // MARK: - History

    func selectHistoryItem(_ keyword: String) {
        lastSearchedQuery = ""
        query = keyword
    }

    func removeHistoryItem(at index: Int) {
        guard searchHistory.indices.contains(index) else { return }
        searchHistory.remove(at: index)
        userDefaults.set(searchHistory, forKey: historyKey)
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
        userDefaults.removeObject(forKey: historyKey)
    }

    private func saveToHistory(_ keyword: String) {
        searchHistory.removeAll { $0 == keyword }
        searchHistory.insert(keyword, at: 0)
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        userDefaults.set(searchHistory, forKey: historyKey)
    }
}
