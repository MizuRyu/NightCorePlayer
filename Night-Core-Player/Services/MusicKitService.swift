import Foundation
import MusicKit

// MusicKit のラッパー
protocol MusicKitClient: Sendable {
    func requestAuthorization() async -> MusicAuthorization.Status
    func searchCatalogSongs(term: String, limit: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchSongs(in playlist: Playlist) async throws -> [Song]
}

// 実体
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

protocol MusicKitService: Sendable {
    func ensureAuth() async throws -> Void
    func searchSongs(keyword: String, limit: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchPlaylistSongs(in plyalist: Playlist) async throws -> [Song]
}

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
    /// カタログから曲をキーワード検索
    /// - Parameters:
    ///   - keyword: 検索ワード
    ///   - limit: 最大取得件数
    /// - Returns: 検索結果の Song 配列
    func searchSongs(
        keyword: String,
        limit: Int = Constants.MusicAPI.musicKitSearchLimit
    ) async throws -> [Song] {
        try await ensureAuth()
        return try await client.searchCatalogSongs(term: keyword, limit: limit)
    }
    
    /// ライブラリ内のプレイリスト取得
    /// - Parameters:
    ///   - limit: 最大取得件数
    /// - Returns: ユーザーライブラリ内のプレイリスト配列
    /// - Returns: 検索結果の Song 配列
    func fetchLibraryPlaylists(limit: Int = 10) async throws -> [Playlist] {
        try await ensureAuth()
        return try await client.fetchLibraryPlaylists(limit: limit)
    }
    
    /// 指定ライブラリプレイリストの中身を取得
    /// - Parameters:
    ///   - playlist: 曲目を取得するプレイリスト
    /// - Returns: プレイリスト内の Song 配列
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        try await ensureAuth()
        return try await client.fetchSongs(in: playlist)
    }
}
