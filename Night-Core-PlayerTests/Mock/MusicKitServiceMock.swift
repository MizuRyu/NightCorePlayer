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