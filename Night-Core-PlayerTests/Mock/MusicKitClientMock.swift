import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

final class MusicKitClientMock: MusicKitClient, @unchecked Sendable {
    var authStatus: MusicAuthorization.Status = .authorized
    var searchResult: [Song] = []
    var playlists: [Playlist] = []
    var playlistSongs: [Song] = []
    
    private(set) var authorizationRequests = 0
    private(set) var searchCalls: [(term: String, limit: Int)] = []
    private(set) var fetchPlaylistCalls: [Int] = []
    private(set) var fetchSongsCalls: [Playlist] = []
    
    func requestAuthorization() async -> MusicAuthorization.Status {
        authorizationRequests += 1
        return authStatus
    }
    func searchCatalogSongs(term: String, limit: Int) async throws -> [Song] {
        searchCalls.append((term: term, limit: limit))
        return searchResult
    }
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        fetchPlaylistCalls.append(limit)
        return Array(playlists.prefix(limit))
    }
    func fetchSongs(in playlist: Playlist) async throws -> [Song] {
        fetchSongsCalls.append(playlist)
        return playlistSongs    }
}
