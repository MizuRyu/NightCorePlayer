import Foundation
import MediaPlayer
import MusicKit
import NightCoreDomain

// MARK: - キュー再構築とプレイヤーへの反映

extension MusicPlayerServiceImpl {
    func handleQueueAction(_ action: QueueUpdateAction, autoPlay: Bool = true) async {
        switch action {
        case .playNewQueue:
            await syncPlayerQueue(autoPlay: autoPlay, preserveCurrentTime: false)
            updateSnapshot()
        case .updatePlayerQueueOnly:
            await syncPlayerQueue(
                autoPlay: player.playbackState == .playing,
                preserveCurrentTime: true
            )
            updateSnapshot()
        case .playerShouldStop:
            player.stop()
            updateSnapshot()
        case .noAction:
            break
        }
    }

    func applyRepeatModeToPlayer() {
        switch repeatMode {
        case .none:
            player.repeatMode = .none
        case .all:
            player.repeatMode = .all
        case .one:
            player.repeatMode = .one
        }
    }

    func makePlayParameters(for song: Song) throws -> MPMusicPlayerPlayParameters? {
        guard let playParams = song.playParameters else {
            return nil
        }
        let data = try JSONEncoder().encode(playParams)
        return try JSONDecoder().decode(MPMusicPlayerPlayParameters.self, from: data)
    }

    func buildQueueDescriptor(from songs: [Song], startAt index: Int) throws -> MPMusicPlayerPlayParametersQueueDescriptor {
        guard !songs.isEmpty, songs.indices.contains(index) else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        let target: [Song]
        if repeatMode == .one {
            target = [songs[index]]
        } else if repeatMode == .all {
            target = Array(songs[index...]) + Array(songs[..<index])
        } else {
            target = Array(songs[index...])
        }
        let params = try target.compactMap { try makePlayParameters(for: $0) }
        guard !params.isEmpty else {
            throw NSError(domain: "MusicPlayerUtils", code: -2, userInfo: nil)
        }
        return MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: params)
    }

    func syncPlayerQueue(autoPlay: Bool, preserveCurrentTime: Bool) async {
        lastPlayerIndex = nil
        pendingNativeNowPlayingIndex = nil
        pendingShuffleResync = false

        guard let descriptor = try? buildQueueDescriptor(from: queue.items, startAt: queue.currentIndex) else {
            player.stop()
            return
        }

        let currentPos = preserveCurrentTime ? player.currentTime : 0
        player.setQueue(with: descriptor)
        if autoPlay {
            do {
                try await player.prepareToPlay()
            } catch {
                #if DEBUG
                    logger.error("prepareToPlay failed: \(error.localizedDescription)")
                #endif
                playbackErrorSubject.send(error)
                return
            }
            if preserveCurrentTime {
                player.seek(to: currentPos)
            }
            player.play()
        } else if preserveCurrentTime {
            player.seek(to: currentPos)
        }
        applyRepeatModeToPlayer()
        player.playbackRate = currentPlaybackRate
    }
}
