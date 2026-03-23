import Foundation
import MusicKit
import SwiftUI

// MARK: - Protocol

/// Apple Music カタログとの対話を担当する（Catalog コンテキスト）
protocol MusicKitService: Sendable {
    func ensureAuth() async throws -> Void
    func searchSongs(keyword: String, limit: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song]
}

// MARK: - MusicKitClient

/// MusicKit API の低レベルラッパー
protocol MusicKitClient: Sendable {
    func requestAuthorization() async -> MusicAuthorization.Status
    func searchCatalogSongs(term: String, limit: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchSongs(in playlist: Playlist) async throws -> [Song]
}

struct DefaultMusicKitClient: MusicKitClient {
    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }
    func searchCatalogSongs(term: String, limit: Int) async throws -> [Song] {
        var req = MusicCatalogSearchRequest(term: term, types: [Song.self])
        req.limit = limit
        let res = try await req.response()
        return Array(res.songs)
    }
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        var req = MusicLibraryRequest<Playlist>()
        req.limit = limit
        let res = try await req.response()
        return Array(res.items.prefix(limit))
    }
    func fetchSongs(in playlist: Playlist) async throws -> [Song] {
        let detailed: Playlist = try await playlist.with([.tracks])
        return detailed.tracks?
            .compactMap { track in
                if case let .song(song) = track { return song }
                else { return nil}
            }
        ?? []
    }
}

// MARK: - MusicKitServiceImpl

final class MusicKitServiceImpl: MusicKitService {
    private let client: MusicKitClient

    init(client: MusicKitClient = DefaultMusicKitClient()) {
        self.client = client
    }
    func ensureAuth() async throws -> Void {
        let status = await client.requestAuthorization()
        guard status == .authorized else {
            throw NSError(
                domain: "MusicKit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MusicKit の権限がありません"]
            )
        }
    }
    func searchSongs(
        keyword: String,
        limit: Int = Constants.MusicAPI.musicKitSearchLimit
    ) async throws -> [Song] {
        try await ensureAuth()
        return try await client.searchCatalogSongs(term: keyword, limit: limit)
    }
    func fetchLibraryPlaylists(limit: Int = 10) async throws -> [Playlist] {
        try await ensureAuth()
        return try await client.fetchLibraryPlaylists(limit: limit)
    }
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        try await ensureAuth()
        return try await client.fetchSongs(in: playlist)
    }
}

// MARK: - SwiftUI Environment 対応

private struct MusicKitServiceKey: EnvironmentKey {
    static let defaultValue: any MusicKitService = MusicKitServiceImpl()
}

extension EnvironmentValues {
    var musicKitService: any MusicKitService {
        get { self[MusicKitServiceKey.self] }
        set { self[MusicKitServiceKey.self] = newValue }
    }
}
