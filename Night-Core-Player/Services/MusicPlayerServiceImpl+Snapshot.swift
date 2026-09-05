import Foundation
import MediaPlayer
import NightCoreDomain

// MARK: - スナップショット生成と now playing 追従

extension MusicPlayerServiceImpl {
    func updateSnapshot() {
        let item = player.nowPlayingItem
        let song = queue.currentSong
        let timestamp = now()
        let currentTime = player.currentTime

        allowanceEnforcer?.tick(
            isPlaying: player.playbackState == .playing,
            rate: currentPlaybackRate,
            songID: song?.id.rawValue,
            // 再生対象がない状態では NaN になり得る。消費計算の基準にできないためnilを渡す
            playbackPosition: currentTime.isFinite ? currentTime : nil,
            now: timestamp
        )

        // 猶予対象外の曲での倍速は曲末を待たず等速へ戻す（等速再生自体は止めない）
        revertToNormalRateIfNeeded()

        let title = song?.title ?? item?.title ?? "-"
        let artist = song?.artistName ?? item?.artist ?? "-"
        let duration = song?.duration ?? item?.playbackDuration ?? 0

        guard let song = song else {
            snapshot = MusicPlayerSnapshot.empty
            return
        }

        let currentID = song.id.rawValue
        let isNewSong = (lastSnapshotSongID != currentID)

        // MPMusicPlayerController.pause() の playbackState 反映は非同期のため、
        // 停止ブロック内で明示的に書き換えられるよう先に読んでおく
        var isPlaying = player.playbackState == .playing
        let rate = currentPlaybackRate

        // 残高枯渇時は現在の曲の末尾まで再生し、曲替わりのタイミングで停止する（ブツ切り防止）
        if isNewSong, stopAtSongBoundaryIfNeeded(pausePlayer: true) {
            isPlaying = false
        }

        if isNewSong {
            lastSnapshotSongID = currentID
        }

        let existingArtwork = snapshot.artworkData

        snapshot = MusicPlayerSnapshot(
            title: title,
            artist: artist,
            artworkData: existingArtwork,
            currentTime: currentTime,
            duration: duration,
            rate: rate,
            isPlaying: isPlaying
        )

        guard isNewSong else { return }

        if let newSong = queue.currentSong {
            do {
                try historyManager.append(newSong)
            } catch {
                logger.error("History append error: \(error.localizedDescription)")
            }
        }
        saveState()

        Task { [weak self] in
            guard let self = self else { return }
            let fetchedData = await self.artworkService.getArtwork(for: song)
            // 取得完了時点のライブ値で再構築し、古い再生状態（rate/isPlaying）を再配信しない
            let updated = MusicPlayerSnapshot(
                title: title,
                artist: artist,
                artworkData: fetchedData,
                currentTime: self.player.currentTime,
                duration: duration,
                rate: self.currentPlaybackRate,
                isPlaying: self.player.playbackState == .playing
            )
            self.snapshot = updated
        }
    }

    func trackChanged() {
        let playerIndex = player.indexOfNowPlayingItem

        if let pendingIndex = pendingNativeNowPlayingIndex {
            pendingNativeNowPlayingIndex = nil
            lastPlayerIndex = playerIndex
            if queue.items.indices.contains(pendingIndex) {
                queue.currentIndex = pendingIndex
            }
            updateSnapshot()
            return
        }

        if needsQueueRefresh {
            needsQueueRefresh = false
            Task { [weak self] in
                await self?.handleQueueAction(.updatePlayerQueueOnly)
            }
        }

        // 明示的なキュー更新直後（next/previous/setQueue経由）は
        // lastPlayerIndex が nil にリセットされている。
        // currentIndex は既に正しいので、ベースラインだけ記録して終了。
        if lastPlayerIndex == nil {
            lastPlayerIndex = playerIndex
            updateSnapshot()
            return
        }

        guard playerIndex != lastPlayerIndex else { return }

        let previousPlayerIndex = lastPlayerIndex!
        lastPlayerIndex = playerIndex

        guard playerIndex >= 0, !queue.items.isEmpty else {
            updateSnapshot()
            return
        }

        // nowPlayingItem の ID で内部キューを照合（シャッフル時も正確）
        if let nowPlaying = player.nowPlayingItem,
           let persistentID = nowPlaying.value(forProperty: MPMediaItemPropertyPersistentID) as? UInt64 {
            let idString = String(persistentID)
            if let matchIndex = queue.items.firstIndex(where: { $0.id.rawValue == idString }) {
                queue.currentIndex = matchIndex
                updateSnapshot()
                return
            }
        }

        // ID 照合できない場合は delta ベースのフォールバック
        let delta = playerIndex - previousPlayerIndex
        let newIndex = queue.currentIndex + delta

        if newIndex >= 0, newIndex < queue.items.count {
            queue.currentIndex = newIndex
        } else if newIndex < 0 {
            let baseIndex = queue.currentIndex - previousPlayerIndex
            let wrapped = max(baseIndex + playerIndex, 0)
            queue.currentIndex = min(wrapped, queue.items.count - 1)
        } else {
            queue.currentIndex = queue.items.count - 1
        }

        updateSnapshot()
    }
}
