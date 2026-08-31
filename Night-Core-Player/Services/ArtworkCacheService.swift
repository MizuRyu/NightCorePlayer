import Foundation
import UIKit
import MusicKit
import NightCoreDomain
import os

// MARK: - Protocol

@MainActor
protocol ArtworkCacheService: Sendable {
    func getArtwork(for song: Song?) async -> Data?
}

// MARK: - Impl

@MainActor
final class ArtworkCacheServiceImpl: ArtworkCacheService {
    private let artworkCache = NSCache<NSString, NSData>()
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Artwork")

    func getArtwork(for song: Song?) async -> Data? {
        guard let song = song else { return nil }

        let cacheKey = NSString(string: song.id.rawValue)
        if let cached = artworkCache.object(forKey: cacheKey) {
            return cached as Data
        }

        let detailed = await fetchSongDetails(song)
        if let data = await fetchArtwork(from: detailed.artwork) {
            artworkCache.setObject(data as NSData, forKey: cacheKey)
            return data
        }

        if let data = await fetchArtwork(from: song.artwork) {
            artworkCache.setObject(data as NSData, forKey: cacheKey)
            return data
        }

        return nil
    }

    // MARK: - Private

    private func fetchSongDetails(_ song: Song) async -> Song {
        guard !song.id.rawValue.isEmpty else { return song }
        let raw = song.id.rawValue
        if raw.hasPrefix("i.") { return song }
        do {
            let req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: song.id)
            let resp = try await req.response()
            return resp.items.first ?? song
        } catch {
            logger.error("fetchSongDetails error: \(error.localizedDescription)")
            return song
        }
    }

    private func fetchArtwork(from art: Artwork?) async -> Data? {
        guard let art = art,
              let url = art.url(
                  width: Int(Constants.MusicPlayer.artworkSize),
                  height: Int(Constants.MusicPlayer.artworkSize)
              )
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard UIImage(data: data) != nil else { return nil }
            return data
        } catch {
            logger.error("Artwork Download Error: \(error.localizedDescription)")
            return nil
        }
    }
}
