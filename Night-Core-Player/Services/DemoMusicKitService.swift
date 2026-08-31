import Foundation
import MusicKit

/// -DEMO 起動引数時のみ composition root から注入される MusicKit スタブ。
/// シミュレータは FairPlay 非対応のため Apple Music のカタログ・ライブラリ系 API が機能しないので、
/// カタログ取得系のみシードデータを返し、再生指示は既存の MPMusicPlayerAdapter 経由へそのまま流す。
/// MusicAuthorization.request() は ensureAuth を no-op にすることで迂回する。
struct DemoMusicKitService: MusicKitService {
    private struct DemoTrack {
        let id: String
        let title: String
        let artist: String
        let duration: TimeInterval
    }

    private struct DemoPlaylist {
        let id: String
        let name: String
        let trackIDs: [String]
    }

    private static let demoTracks: [DemoTrack] = [
        DemoTrack(id: "demo-song-001", title: "夜間飛行", artist: "Lumen Sky", duration: 213),
        DemoTrack(id: "demo-song-002", title: "Midnight Circuit", artist: "電光都市エキスポ", duration: 187),
        DemoTrack(id: "demo-song-003", title: "星屑ラビリンス", artist: "Aozora Collective", duration: 244),
        DemoTrack(id: "demo-song-004", title: "Neon Rainfall", artist: "夜光アンサンブル", duration: 198),
        DemoTrack(id: "demo-song-005", title: "朝焼けテレスコープ", artist: "Lumen Sky", duration: 226),
        DemoTrack(id: "demo-song-006", title: "Gravity Zero Dance", artist: "プラズマ少年団", duration: 205)
    ]

    private static let demoPlaylists: [DemoPlaylist] = [
        DemoPlaylist(
            id: "demo-playlist-001",
            name: "深夜ドライブ",
            trackIDs: ["demo-song-001", "demo-song-002", "demo-song-004"]
        ),
        DemoPlaylist(
            id: "demo-playlist-002",
            name: "朝のリセット",
            trackIDs: ["demo-song-005", "demo-song-003", "demo-song-006"]
        )
    ]

    private static let seedSongs: [Song] = demoTracks.compactMap { track in
        Self.makeItem(
            Song.self,
            id: track.id,
            kind: "songs",
            attributes: [
                "name": track.title,
                "artistName": track.artist,
                "durationInMillis": Int(track.duration * 1000)
            ]
        )
    }

    private static let seedArtists: [Artist] = {
        let names = Array(Set(demoTracks.map(\.artist))).sorted()
        return names.enumerated().compactMap { index, name in
            Self.makeItem(Artist.self, id: "demo-artist-\(index + 1)", kind: "artists", attributes: ["name": name])
        }
    }()

    private static let seedPlaylists: [Playlist] = demoPlaylists.compactMap { playlist in
        Self.makeItem(Playlist.self, id: playlist.id, kind: "playlists", attributes: ["name": playlist.name])
    }

    // MARK: - MusicKitService

    func ensureAuth() async throws {}

    func searchSongs(keyword: String, limit: Int, offset: Int) async throws -> [Song] {
        Array(Self.matchedSongs(keyword: keyword).dropFirst(offset).prefix(limit))
    }

    func searchArtists(keyword: String, limit: Int) async throws -> [Artist] {
        let matched = Self.seedArtists.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        return Array(matched.prefix(limit))
    }

    func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
        Array(Self.artistSongs(of: artist).prefix(25))
    }

    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song] {
        Array(Self.artistSongs(of: artist).dropFirst(offset).prefix(limit))
    }

    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        Array(Self.seedPlaylists.prefix(limit))
    }

    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        guard let demoPlaylist = Self.demoPlaylists.first(where: { $0.id == playlist.id.rawValue }) else {
            return []
        }
        let ids = Set(demoPlaylist.trackIDs)
        return Self.seedSongs.filter { ids.contains($0.id.rawValue) }
    }

    func fetchPersonalRecommendations(history _: [Song], limit: Int) async throws -> [Song] {
        Array(Self.seedSongs.shuffled().prefix(limit))
    }

    // MARK: - Private

    private static func matchedSongs(keyword: String) -> [Song] {
        seedSongs.filter { song in
            song.title.localizedCaseInsensitiveContains(keyword)
                || song.artistName.localizedCaseInsensitiveContains(keyword)
        }
    }

    private static func artistSongs(of artist: Artist) -> [Song] {
        seedSongs.filter { $0.artistName == artist.name }
    }

    /// MusicKit の Song/Artist/Playlist は public init を持たないため、Apple Music API 形式の JSON 経由で生成する
    private static func makeItem<T: Decodable>(
        _ type: T.Type,
        id: String,
        kind: String,
        attributes: [String: Any]
    ) -> T? {
        let object: [String: Any] = ["id": id, "type": kind, "attributes": attributes]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let item = try? JSONDecoder().decode(type, from: data) else { return nil }
        return item
    }
}
