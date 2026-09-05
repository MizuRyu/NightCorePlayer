import Foundation
import MediaPlayer
import NightCoreDomain

// MARK: - 状態の復元と保存

extension MusicPlayerServiceImpl {
    func restore() async {
        // #69 で構造体化するまでの暫定
        // swiftlint:disable:next large_tuple
        let st: (queueIDs: [String], currentIndex: Int, playbackRate: Double, shuffleModeRaw: Int, repeatModeRaw: Int, isAutoPlayEnabled: Bool)
        do {
            st = try persistenceService.loadState()
        } catch {
            st = ([], 0, Constants.MusicPlayer.defaultPlaybackRate,
                  MPMusicShuffleMode.off.rawValue, MPMusicRepeatMode.none.rawValue, false)
        }

        let restoredRepeat = MPMusicRepeatMode(rawValue: st.repeatModeRaw) ?? .none
        isShuffled = st.shuffleModeRaw != Int(MPMusicShuffleMode.off.rawValue)
        switch restoredRepeat {
        case .all: repeatMode = .all
        case .one: repeatMode = .one
        default: repeatMode = .none
        }
        isAutoPlayEnabled = st.isAutoPlayEnabled

        do {
            let songs = try await persistenceService.fetchCatalogSongs(st.queueIDs)
            await self.setQueue(songs: songs, startAt: st.currentIndex, autoPlay: false)
        } catch {
            await self.setQueue(songs: [], startAt: 0, autoPlay: false)
        }

        let historyIDs: [String]
        do {
            historyIDs = try persistenceService.loadHistoryIDs()
        } catch {
            historyIDs = []
        }
        do {
            let historySongs = try await persistenceService.fetchCatalogSongs(historyIDs)
            historyManager.restoreHistory(historySongs)
        } catch {
            historyManager.restoreHistory([])
        }

        currentPlaybackRate = rateManager.defaultRate
        player.playbackRate = rateManager.defaultRate
        player.shuffleMode = .off // アプリ側シャッフルのため常にoff
        applyRepeatModeToPlayer()
    }

    func saveState() {
        let shuffleModeRaw: Int = isShuffled
            ? Int(MPMusicShuffleMode.songs.rawValue)
            : Int(MPMusicShuffleMode.off.rawValue)

        let repeatModeRaw: Int
        switch repeatMode {
        case .all: repeatModeRaw = Int(MPMusicRepeatMode.all.rawValue)
        case .one: repeatModeRaw = Int(MPMusicRepeatMode.one.rawValue)
        case .none: repeatModeRaw = Int(MPMusicRepeatMode.none.rawValue)
        }

        do {
            try persistenceService.saveQueueState(
                queueIDs: queue.items.map { $0.id.rawValue },
                currentIndex: queue.currentIndex,
                playbackRate: rateManager.defaultRate,
                shuffleModeRaw: shuffleModeRaw,
                repeatModeRaw: repeatModeRaw,
                isAutoPlayEnabled: isAutoPlayEnabled
            )
        } catch {
            logger.error("State save error: \(error.localizedDescription)")
        }
    }
}
