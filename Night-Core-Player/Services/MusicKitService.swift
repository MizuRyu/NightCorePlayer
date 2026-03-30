import Foundation
import MusicKit
import SwiftUI

// MARK: - Protocol

protocol MusicKitService: Sendable {
    func ensureAuth() async throws -> Void
    func searchSongs(keyword: String, limit: Int, offset: Int) async throws -> [Song]
    func searchArtists(keyword: String, limit: Int) async throws -> [Artist]
    func fetchArtistTopSongs(artist: Artist) async throws -> [Song]
    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song]
    func fetchPersonalRecommendations(limit: Int) async throws -> [Song]
}

extension MusicKitService {
    func searchSongs(keyword: String, limit: Int) async throws -> [Song] {
        try await searchSongs(keyword: keyword, limit: limit, offset: 0)
    }
}

enum PlaylistSongsFetchError: LocalizedError {
    case tracksUnavailable(name: String, playlistID: String, kind: String?, reason: String?)
    case emptyPlaylist(name: String, playlistID: String, kind: String?)

    var errorDescription: String? {
        switch self {
        case let .tracksUnavailable(name, _, _, reason):
            if let reason, !reason.isEmpty {
                return "プレイリスト「\(name)」の曲を取得できませんでした: \(reason)"
            }
            return "プレイリスト「\(name)」の曲を取得できませんでした"
        case let .emptyPlaylist(name, _, _):
            return "プレイリスト「\(name)」には表示できる曲がありません"
        }
    }
}

// MARK: - MusicKitClient

protocol MusicKitClient: Sendable {
    func requestAuthorization() async -> MusicAuthorization.Status
    func searchCatalogSongs(term: String, limit: Int, offset: Int) async throws -> [Song]
    func searchCatalogArtists(term: String, limit: Int) async throws -> [Artist]
    func fetchArtistTopSongs(artist: Artist) async throws -> [Song]
    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song]
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist]
    func fetchSongs(in playlist: Playlist) async throws -> [Song]
}

extension MusicKitClient {
    func searchCatalogSongs(term: String, limit: Int) async throws -> [Song] {
        try await searchCatalogSongs(term: term, limit: limit, offset: 0)
    }
}

struct DefaultMusicKitClient: MusicKitClient {
    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }
    func searchCatalogSongs(term: String, limit: Int, offset: Int = 0) async throws -> [Song] {
        var req = MusicCatalogSearchRequest(term: term, types: [Song.self])
        req.limit = limit
        req.offset = offset
        let res = try await req.response()
        return Array(res.songs)
    }
    func searchCatalogArtists(term: String, limit: Int) async throws -> [Artist] {
        var req = MusicCatalogSearchRequest(term: term, types: [Artist.self])
        req.limit = limit
        let res = try await req.response()
        return Array(res.artists)
    }
    func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
        let detailed = try await artist.with([.topSongs])
        let top = Array(detailed.topSongs ?? [])
        if !top.isEmpty { return Array(top.prefix(25)) }

        // topSongs が空の場合、アーティスト名でカタログ検索にフォールバック
        var req = MusicCatalogSearchRequest(term: artist.name, types: [Song.self])
        req.limit = 25
        let res = try await req.response()
        return Array(res.songs)
    }
    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song] {
        var req = MusicCatalogSearchRequest(term: artist.name, types: [Song.self])
        req.limit = limit
        req.offset = offset
        let res = try await req.response()
        return res.songs.filter { song in
            song.artistURL == artist.url || song.artistName == artist.name
        }
    }
    func fetchLibraryPlaylists(limit: Int) async throws -> [Playlist] {
        var req = MusicLibraryRequest<Playlist>()
        req.limit = limit
        let res = try await req.response()
        return Array(res.items.prefix(limit))
    }
    func fetchSongs(in playlist: Playlist) async throws -> [Song] {
        let playlistID = playlist.id.rawValue
        let playlistKind = playlist.kind.map { String(describing: $0) }
        var lastErrorDescription: String?

        do {
            let detailed: Playlist = try await playlist.with([.tracks])
            let songs = extractSongs(from: detailed.tracks)
            if !songs.isEmpty {
                return songs
            }
        } catch {
            lastErrorDescription = error.localizedDescription
            #if DEBUG
            print("⚠️ playlist.with([.tracks]) failed: \(error.localizedDescription)")
            #endif
        }

        var req = MusicLibraryRequest<Playlist>()
        req.filter(matching: \.id, equalTo: playlist.id)
        let res = try await req.response()
        guard let libraryPlaylist = res.items.first else {
            throw PlaylistSongsFetchError.tracksUnavailable(
                name: playlist.name,
                playlistID: playlistID,
                kind: playlistKind,
                reason: lastErrorDescription
            )
        }

        do {
            let detailed = try await libraryPlaylist.with([.tracks])
            let songs = extractSongs(from: detailed.tracks)
            if !songs.isEmpty {
                return songs
            }
        } catch {
            lastErrorDescription = error.localizedDescription
            #if DEBUG
            print("⚠️ libraryPlaylist.with([.tracks]) failed: \(error.localizedDescription)")
            #endif
        }

        do {
            let detailed = try await libraryPlaylist.with([.entries])
            let songs = extractSongs(from: detailed.entries)
            if !songs.isEmpty {
                return songs
            }
            throw PlaylistSongsFetchError.emptyPlaylist(
                name: playlist.name,
                playlistID: playlistID,
                kind: playlistKind
            )
        } catch let error as PlaylistSongsFetchError {
            throw error
        } catch {
            lastErrorDescription = error.localizedDescription
            #if DEBUG
            print("⚠️ libraryPlaylist.with([.entries]) failed: \(error.localizedDescription)")
            #endif
        }

        throw PlaylistSongsFetchError.tracksUnavailable(
            name: playlist.name,
            playlistID: playlistID,
            kind: playlistKind,
            reason: lastErrorDescription
        )
    }

    private func extractSongs(from tracks: MusicItemCollection<Track>?) -> [Song] {
        tracks?.compactMap { track -> Song? in
            if case let .song(song) = track { return song }
            return nil
        } ?? []
    }

    @available(iOS 16.0, *)
    private func extractSongs(from entries: MusicItemCollection<Playlist.Entry>?) -> [Song] {
        entries?.compactMap { entry -> Song? in
            if case let .song(song)? = entry.item { return song }
            return nil
        } ?? []
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
        limit: Int = Constants.MusicAPI.musicKitSearchLimit,
        offset: Int = 0
    ) async throws -> [Song] {
        try await ensureAuth()
        return try await client.searchCatalogSongs(term: keyword, limit: limit, offset: offset)
    }
    func searchArtists(
        keyword: String,
        limit: Int = 5
    ) async throws -> [Artist] {
        try await ensureAuth()
        return try await client.searchCatalogArtists(term: keyword, limit: limit)
    }
    func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
        try await ensureAuth()
        return try await client.fetchArtistTopSongs(artist: artist)
    }
    func fetchArtistSongs(artist: Artist, limit: Int, offset: Int) async throws -> [Song] {
        try await ensureAuth()
        return try await client.fetchArtistSongs(artist: artist, limit: limit, offset: offset)
    }
    func fetchLibraryPlaylists(limit: Int = 10) async throws -> [Playlist] {
        try await ensureAuth()
        return try await client.fetchLibraryPlaylists(limit: limit)
    }
    func fetchPlaylistSongs(in playlist: Playlist) async throws -> [Song] {
        try await ensureAuth()
        let songs = try await client.fetchSongs(in: playlist)
        #if DEBUG
        print("🎵 fetchPlaylistSongs: \(songs.count) songs loaded for '\(playlist.name)' [id=\(playlist.id.rawValue)]")
        #endif
        return songs
    }

    func fetchPersonalRecommendations(limit: Int = Constants.Recommendation.defaultLimit) async throws -> [Song] {
        try await ensureAuth()

        // ユーザーライブラリのプレイリストから推薦楽曲を取得
        let playlists = try await client.fetchLibraryPlaylists(limit: 5)
        var songs: [Song] = []
        for playlist in playlists {
            let playlistSongs = try await client.fetchSongs(in: playlist)
            songs.append(contentsOf: playlistSongs)
            if songs.count >= limit { break }
        }
        return Array(songs.shuffled().prefix(limit))
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
