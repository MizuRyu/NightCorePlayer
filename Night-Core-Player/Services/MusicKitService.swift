import Foundation
import MusicKit

/// 楽曲検索 API
struct MusicKitService {
    /// カタログから曲をキーワード検索
    /// - Parameters:
    ///   - keyword: 検索ワード
    ///   - limit: 最大取得件数
    /// - Returns: 検索結果の Song 配列
    static func searchSongs(
        keyword: String,
        limit: Int = 10
    ) async throws -> [Song] {
        // 認可リクエスト（初回のみダイアログが表示）
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw NSError(domain: "MusicKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "MusicKit の権限がありません"])
        }
        
        var request = MusicCatalogSearchRequest(term: keyword, types: [Song.self])
        request.limit = limit
        
        let response = try await request.response()
        
        return Array(response.songs)
    }
}
