import Combine
import MediaPlayer
import MusicKit
import Foundation

// MARK: - PlayerControllable

// 注記: MediaPlayer 型（MPMusicPlaybackState 等）を参照している。
// Apple Music 専用アプリのため Domain への MediaPlayer 依存を許容する。
@MainActor
public protocol PlayerControllable: Sendable {
    var playbackState: MPMusicPlaybackState { get }
    var currentTime: TimeInterval { get }
    var nowPlayingItem: MPMediaItem? { get }
    var indexOfNowPlayingItem: Int { get }
    var playbackRate: Double { get set }

    var shuffleMode: MPMusicShuffleMode { get set }
    var repeatMode: MPMusicRepeatMode { get set }

    func play()
    func pause()
    func seek(to time: TimeInterval)
    func skipToNext()
    func skipToPrevious()
    func setQueue(with descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func prepend(_ descriptor: MPMusicPlayerPlayParametersQueueDescriptor)
    func stop()
}

// MARK: - QueueManaging

public enum QueueUpdateAction: Sendable {
    case playNewQueue
    case updatePlayerQueueOnly
    case playerShouldStop
    case noAction
}

@MainActor
public protocol QueueManaging: Sendable {
    var items: [Song] { get }
    var currentIndex: Int { get set }
    var currentSong: Song? { get }
    var isEmpty: Bool { get }

    func setQueue(_ songs: [Song], startAt idx: Int) async -> QueueUpdateAction
    func moveItem(from src: Int, to dst: Int) async -> QueueUpdateAction
    func removeItem(at idx: Int) async -> (action: QueueUpdateAction, removed: Song?)
    func insertNext(_ song: Song) async -> (action: QueueUpdateAction, newIndex: Int?)
    func advanceToNextTrack() async -> Bool
    func regressToPreviousTrack() async -> Bool
    func songsForPlayerQueueDescriptor() async -> [Song]
}

// MARK: - MusicPlayerSnapshot

public struct MusicPlayerSnapshot: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let artworkData: Data?
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let rate: Double
    public let isPlaying: Bool

    public static let empty = MusicPlayerSnapshot(
        title: "-",
        artist: "-",
        artworkData: nil,
        currentTime: 0,
        duration: 0,
        rate: Constants.MusicPlayer.defaultPlaybackRate,
        isPlaying: false
    )
}

// MARK: - MusicPlayerService

@MainActor
protocol MusicPlayerService: Sendable {
    var snapshotPublisher: AnyPublisher<MusicPlayerSnapshot, Never> { get }

    func start() async
    func play() async
    func pause() async
    func next() async
    func previous() async
    func seek(to time: TimeInterval) async
    func setSessionRate(_ rate: Double) async

    func setQueue(songs: [Song], startAt index: Int, autoPlay: Bool) async
    func moveItem(from src: Int, to dst: Int) async
    func removeItem(at idx: Int) async
    func insertNext(_ song: Song) async
    func playNow(_ song: Song) async
    func playNextAndPlay(_ song: Song) async

    var isShuffled: Bool { get }
    var repeatMode: Constants.RepeatMode { get }
    var isAutoPlayEnabled: Bool { get }
    func toggleShuffle() async
    func cycleRepeatMode() async
    func toggleAutoPlay() async

    var musicPlayerQueue: [Song] { get }
    var nowPlayingIndex: Int { get }
    var playHistory: [Song] { get }
    func clearHistory() throws
}
