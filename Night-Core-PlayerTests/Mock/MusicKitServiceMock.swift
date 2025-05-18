import Testing
import Combine
import SwiftUI
import MusicKit
@testable import Night_Core_Player

final class MusicKitServiceMock_Search: MusicKitService {
    private(set) var searchCallArgs: [(keyword: String, limit: Int)] = []

    var stubSongs: [Song] = []
    var stubError: Error?

    func ensureAuth() async throws { }
    func searchSongs(keyword: String, limit: Int) async throws -> [Song] {
        searchCallArgs.append((keyword, limit))
        if let e = stubError { throw e }
        return stubSongs
    }
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] { fatalError() }
    func fetchPlaylistSongs(in: Playlist) async throws -> [Song] { fatalError() }
}

final class MusicKitServiceMock_Playlist: MusicKitService {
    var fetchLibraryPlaylistsCallCount = 0
    var fetchPlaylistSongsCallCount = 0
    
    var fetchLibraryPlaylistsHandler: ((Int) throws -> [Playlist])? = nil
    
    func ensureAuth() async throws {}
    
    func searchSongs(keyword: String, limit: Int) async throws -> [Song] {
        fatalError()
    }
    
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        fetchLibraryPlaylistsCallCount += 1
        if let handler = fetchLibraryPlaylistsHandler {
            return try handler(limit)
        }
        return []
    }
    
    var result: Result<[Song], Error> = .success([])
    
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        fetchPlaylistSongsCallCount += 1
        switch result {
        case .success(let songs):
            return songs
        case .failure(let error):
            throw error
        }
    }
}

