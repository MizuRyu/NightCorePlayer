import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

/// MusicKitService の統一モック
final class MusicKitServiceMock: MusicKitService {
    // MARK: - Search トラッキング
    var searchCallArgs: [(keyword: String, limit: Int)] = []
    var stubSongs: [Song] = []
    var searchError: Error?

    // MARK: - Artist トラッキング
    var searchArtistsCallArgs: [(keyword: String, limit: Int)] = []
    var stubArtists: [Artist] = []
    var searchArtistsError: Error?
    var fetchArtistTopSongsCallCount = 0
    var fetchArtistTopSongsResult: Result<[Song], Error> = .success([])

    // MARK: - Playlist トラッキング
    var fetchLibraryPlaylistsCallCount = 0
    var fetchPlaylistSongsCallCount = 0
    var fetchLibraryPlaylistsHandler: ((Int) throws -> [Playlist])? = nil
    var fetchPlaylistSongsResult: Result<[Song], Error> = .success([])

    // MARK: - Recommendation トラッキング
    var fetchPersonalRecommendationsCallCount = 0
    var stubRecommendationSongs: [Song] = []
    var fetchRecommendationsError: Error?

    // MARK: - Protocol メソッド

    func ensureAuth() async throws { }

    func searchSongs(keyword: String, limit: Int, offset: Int) async throws -> [Song] {
        searchCallArgs.append((keyword, limit))
        if let e = searchError { throw e }
        return stubSongs
    }

    func searchArtists(keyword: String, limit: Int) async throws -> [Artist] {
        searchArtistsCallArgs.append((keyword, limit))
        if let e = searchArtistsError { throw e }
        return stubArtists
    }

    func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
        fetchArtistTopSongsCallCount += 1
        switch fetchArtistTopSongsResult {
        case .success(let songs): return songs
        case .failure(let error): throw error
        }
    }

    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        fetchLibraryPlaylistsCallCount += 1
        if let handler = fetchLibraryPlaylistsHandler {
            return try handler(limit)
        }
        return []
    }

    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        fetchPlaylistSongsCallCount += 1
        switch fetchPlaylistSongsResult {
        case .success(let songs): return songs
        case .failure(let error): throw error
        }
    }

    func fetchPersonalRecommendations(limit: Int) async throws -> [Song] {
        fetchPersonalRecommendationsCallCount += 1
        if let e = fetchRecommendationsError { throw e }
        return Array(stubRecommendationSongs.prefix(limit))
    }
}

// 後方互換エイリアス（テスト移行用、将来削除可）
typealias MusicKitServiceMock_Search = MusicKitServiceMock
typealias MusicKitServiceMock_Playlist = MusicKitServiceMock

