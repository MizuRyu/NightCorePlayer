import Foundation
import MusicKit
import Observation

@Observable
@MainActor
final class ArtistDetailViewModel {
    let artist: Artist
    private(set) var songs: [Song] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMoreSongs = false
    private(set) var errorMessage: String?

    private let musicKitService: MusicKitService
    private var currentOffset: Int = 0

    init(artist: Artist, musicKitService: MusicKitService) {
        self.artist = artist
        self.musicKitService = musicKitService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let topSongs = try await musicKitService.fetchArtistTopSongs(artist: artist)
            songs = topSongs
            currentOffset = topSongs.count
            hasMoreSongs = songs.count < 50
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            songs = []
        }
    }

    /// 再生/シャッフル用に可能な限り多くの曲を取得する
    func loadAllAvailable() async {
        while hasMoreSongs && !isLoadingMore {
            isLoadingMore = true
            defer { isLoadingMore = false }
            do {
                let more = try await musicKitService.searchSongs(
                    keyword: artist.name,
                    limit: Constants.MusicAPI.musicKitSearchLimit,
                    offset: currentOffset
                )
                let existingIDs = Set(songs.map { $0.id })
                let newSongs = more.filter { !existingIDs.contains($0.id) }
                songs.append(contentsOf: newSongs)
                currentOffset += more.count
                hasMoreSongs = more.count >= Constants.MusicAPI.musicKitSearchLimit
                if songs.count >= 50 { break }
            } catch {
                break
            }
        }
    }

    func loadMoreIfNeeded(currentSong: Song) async {
        guard hasMoreSongs, !isLoadingMore,
              currentSong.id == songs.last?.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let more = try await musicKitService.searchSongs(
                keyword: artist.name,
                limit: Constants.MusicAPI.musicKitSearchLimit,
                offset: currentOffset
            )
            let existingIDs = Set(songs.map { $0.id })
            let newSongs = more.filter { !existingIDs.contains($0.id) }
            songs.append(contentsOf: newSongs)
            currentOffset += more.count
            hasMoreSongs = more.count >= Constants.MusicAPI.musicKitSearchLimit
        } catch {
            // 追加読み込みのエラーは握りつぶす
        }
    }
}
