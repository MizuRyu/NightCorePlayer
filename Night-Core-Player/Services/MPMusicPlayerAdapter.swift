import MediaPlayer

/// MPMusicPlayerController を PlayerControllable に適合させるアダプタ
@MainActor
final class MPMusicPlayerAdapter: PlayerControllable {
    private let player = MPMusicPlayerController.applicationQueuePlayer

    init(defaultRate: Double) {
        player.beginGeneratingPlaybackNotifications()
        player.currentPlaybackRate = Float(defaultRate)
        player.shuffleMode = .off
        player.repeatMode = .none
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
    }

    var playbackState: MPMusicPlaybackState { player.playbackState }
    var currentTime: TimeInterval { player.currentPlaybackTime }
    var nowPlayingItem: MPMediaItem? { player.nowPlayingItem }
    var indexOfNowPlayingItem: Int { player.indexOfNowPlayingItem }
    var playbackRate: Double {
        get { Double(player.currentPlaybackRate) }
        set { player.currentPlaybackRate = Float(newValue) }
    }
    var shuffleMode: MPMusicShuffleMode {
        get { player.shuffleMode }
        set { player.shuffleMode = newValue }
    }
    var repeatMode: MPMusicRepeatMode {
        get { player.repeatMode }
        set { player.repeatMode = newValue }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func seek(to time: TimeInterval) { player.currentPlaybackTime = time }
    func skipToNext() { player.skipToNextItem() }
    func skipToPrevious() { player.skipToPreviousItem() }
    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor) { player.setQueue(with: descriptor) }
    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor) { player.prepend(descriptor) }
    func stop() { player.stop() }
}
