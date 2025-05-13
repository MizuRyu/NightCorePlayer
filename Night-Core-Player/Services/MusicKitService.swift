import Foundation
import MusicKit

/// 楽曲検索
struct MusicKitService {
    private static func ensureAuth() async throws -> Void {
        let status = await MusicAuthorization.request()
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
    static func searchSongs(
        keyword: String,
        limit: Int = 10
    ) async throws -> [Song] {
        try await ensureAuth()
        
        var request = MusicCatalogSearchRequest(term: keyword, types: [Song.self])
        request.limit = limit
        
        let response = try await request.response()
        
        return Array(response.songs)
    }
    
    /// ライブラリ内のプレイリスト取得
    /// - Parameters:
    ///   - limit: 最大取得件数
    /// - Returns: ユーザーライブラリ内のプレイリスト配列
    /// - Returns: 検索結果の Song 配列
    static func fetchLibraryPlaylists(limit: Int = 10) async throws -> [Playlist] {
        try await ensureAuth()
        var request = MusicLibraryRequest<Playlist>()
        request.limit = limit
        let response = try await request.response()
        return Array(response.items.prefix(limit))
    }
    
    /// 指定ライブラリプレイリストの中身を取得
    /// - Parameters:
    ///   - playlist: 曲目を取得するプレイリスト
    /// - Returns: プレイリスト内の Song 配列
    static func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        try await ensureAuth()
        let detailed: Playlist = try await playlist.with([.tracks])
        let tracks: [Song] = detailed.tracks?
            .compactMap { track in
                if case let .song(song) = track { return song }
                else { return nil }
            }
        ?? []
        return tracks
    }
}
