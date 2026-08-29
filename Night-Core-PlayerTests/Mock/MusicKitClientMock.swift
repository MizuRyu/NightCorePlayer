import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

final class MusicKitClientMock: MusicKitClient, @unchecked Sendable {
    var authStatus: MusicAuthorization.Status = .authorized
    var searchResult: [Song] = []
    var artistSearchResult: [Artist] = []
    var artistTopSongs: [Song] = []
    var artistSongs: [Song] = []
    var playlists: [Playlist] = []
    var playlistSongs: [Song] = []
    var recentlyPlayedSongs: [Song] = []
    var recentlyPlayedError: Error?
    var similarArtists: [Artist] = []
    var similarArtistsError: Error?
    /// アーティストIDごとの topSongs (未登録は artistTopSongs にフォールバック)
    var artistTopSongsByID: [String: [Song]] = [:]

    private(set) var authorizationRequests = 0
    private(set) var searchCalls: [(term: String, limit: Int)] = []
    private(set) var searchArtistCalls: [(term: String, limit: Int)] = []
    private(set) var fetchArtistTopSongsCalls = 0
    private(set) var fetchArtistSongsCalls: [(limit: Int, offset: Int)] = []
    private(set) var fetchPlaylistCalls: [Int] = []
    private(set) var fetchSongsCalls: [Playlist] = []
    private(set) var fetchRecentlyPlayedCalls = 0
    private(set) var fetchSimilarArtistsCalls = 0

    func requestAuthorization() async -> MusicAuthorization.Status {
        authorizationRequests += 1
        return authStatus
    }
    func searchCatalogSongs(term: String, limit: Int, offset: Int) async throws -> [Song] {
        searchCalls.append((term: term, limit: limit))
        return searchResult
    }
    func searchCatalogArtists(term: String, limit: Int) async throws -> [Artist] {
        searchArtistCalls.append((term: term, limit: limit))
        return Array(artistSearchResult.prefix(limit))
    }
    func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
        fetchArtistTopSongsCalls += 1
        return artistTopSongsByID[artist.id.rawValue] ?? artistTopSongs
    }
    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song] {
        fetchArtistSongsCalls.append((limit: limit, offset: offset))
        return Array(artistSongs.dropFirst(offset).prefix(limit))
    }
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        fetchPlaylistCalls.append(limit)
        return Array(playlists.prefix(limit))
    }
    func fetchSongs(in playlist: Playlist) async throws -> [Song] {
        fetchSongsCalls.append(playlist)
        return playlistSongs    }
    func fetchRecentlyPlayedSongs(limit: Int) async throws -> [Song] {
        fetchRecentlyPlayedCalls += 1
        if let e = recentlyPlayedError { throw e }
        return Array(recentlyPlayedSongs.prefix(limit))
    }
    func fetchSimilarArtists(artist: Artist) async throws -> [Artist] {
        fetchSimilarArtistsCalls += 1
        if let e = similarArtistsError { throw e }
        return similarArtists
    }
}
