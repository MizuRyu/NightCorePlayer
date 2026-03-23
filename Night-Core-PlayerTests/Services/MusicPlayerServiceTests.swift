import Testing
import SwiftUI
import MediaPlayer
import MusicKit

@testable import Night_Core_Player

// MARK: - SUT 構造体
private struct SUT {
    let service: MusicPlayerServiceImpl
    let adapter: PlayerControllableMock
    let queueMock: QueueManagingMock
    let rateManager: PlaybackRateManagerImpl
    let repo: PlayerStateRepository

    @MainActor
    static func make() -> SUT {
        let adapter   = PlayerControllableMock()
        let queueMock = QueueManagingMock()
        let context = AppDataStore.shared.container.mainContext
        let repo = PlayerStateRepository(context: context)
        let historyRepo = HistoryRepository(context: context)
        let rateManager = PlaybackRateManagerImpl(repo: repo)
        let persistenceService = PlayerPersistenceServiceImpl(
            playerStateRepo: repo, historyRepo: historyRepo
        )
        let historyManager = PlayHistoryManagerImpl(historyRepo: historyRepo)
        let artworkService = ArtworkCacheServiceImpl()
        let service   = MusicPlayerServiceImpl(
            rateManager: rateManager,
            persistenceService: persistenceService,
            historyManager: historyManager,
            artworkService: artworkService,
            playerAdapter: adapter,
            queueManager: queueMock
        )
        return SUT(service: service, adapter: adapter, queueMock: queueMock,
                   rateManager: rateManager, repo: repo)
    }
}

// MARK: - MusicQueueManager Tests
@Suite
@MainActor
struct MusicQueueManagerTests {
    @Test("setQueue: 空配列なら playerShouldStop & currentIndex=0")
    func testSetQueueEmpty() async {
        // Given: 空のMusicQueueManagerを作成
        let mgr = MusicQueueManager()
        // When: setQueueを空配列で呼び出す（startAt: 5）
        let action = await mgr.setQueue([], startAt: 5)
        // Then: playerShouldStopが返り、キューは空、currentIndexは0
        #expect(action == .playerShouldStop)
        #expect(mgr.items.isEmpty)
        #expect(mgr.currentIndex == 0)
    }

    @Test("setQueue: startAt 下限を clamp すること")
    func testSetQueueClampLower() async {
        // Given: 2曲入りの配列を作成
        let mgr = MusicQueueManager()
        let songs = [makeDummySong(id: "A"), makeDummySong(id: "B")]
        // When: startAtを-1でセット
        let action = await mgr.setQueue(songs, startAt: -1)
        // Then: playNewQueueになり、currentIndexは0
        #expect(action == .playNewQueue)
        #expect(mgr.currentIndex == 0)
    }

    @Test("setQueue: startAt 上限を clamp すること")
    func testSetQueueClampUpper() async {
        // Given: 2曲入りの配列を作成
        let mgr = MusicQueueManager()
        let songs = [makeDummySong(id: "A"), makeDummySong(id: "B")]
        // When: startAtを999でセット
        let action = await mgr.setQueue(songs, startAt: 999)
        // Then: playNewQueueになり、currentIndexは末尾になる
        #expect(action == .playNewQueue)
        #expect(mgr.currentIndex == songs.count - 1)
    }

    @Test("moveItem: src==dst の場合は noAction")
    func testMoveItemNoOp() async {
        // Given: 3曲入りのキュー、currentIndex=1
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C")],
            startAt: 1
        )
        // When: 同じ位置（1→1）でmoveItem
        let action = await mgr.moveItem(from: 1, to: 1)
        // Then: noActionが返り、順序もcurrentIndexも変わらない
        #expect(action == .noAction)
        #expect(mgr.items.map(\.id.rawValue) == ["A","B","C"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("moveItem: 楽曲を前方に移動できること")
    func testMoveItemForward() async {
        // Given: 3曲入りのキュー、currentIndex=1
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C")],
            startAt: 1
        )
        // When: BをAの前に移動
        let action = await mgr.moveItem(from: 1, to: 0)
        // Then: updatePlayerQueueOnlyが返り、Bが先頭に
        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items.map(\.id.rawValue) == ["B","A","C"])
    }

    @Test("moveItem: 楽曲を後方に移動できること")
    func testMoveItemBackward() async {
        // Given: 3曲入りのキュー、currentIndex=0
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"),
             makeDummySong(id: "B"),
             makeDummySong(id: "C")],
            startAt: 0
        )
        // When: AをCの後ろに移動
        let action = await mgr.moveItem(from: 0, to: 2)
        // Then: updatePlayerQueueOnlyが返り、Aが末尾に
        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items.map(\.id.rawValue) == ["B","C","A"])
    }

    @Test("moveItem: 非再生中の曲を移動すると即時再生操作は呼ばれず、フラグだけ立つ")
    func testMoveItemNonCurrent() async {
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        // A(0) 再生中
        await sut.service.setQueue(songs: [A,B,C], startAt: 0)
        let beforeSet = sut.adapter.setQueueDescriptors.count
        let beforeSeek = sut.adapter.seekArgs.count
        // C(2) を 1 に移動
        await sut.service.moveItem(from: 2, to: 1)
        // すぐには adapter.setQueue も seek も呼ばれない
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet)
        #expect(sut.adapter.seekArgs.count == beforeSeek)
    }


    @Test("removeItem: 1曲のみなら playerShouldStop")
    func testRemoveItemSingle() async {
        // Given: 1曲だけのキュー
        let mgr = MusicQueueManager()
        await mgr.setQueue([makeDummySong(id: "A")], startAt: 0)
        // When: 唯一の曲を削除
        let (action, removed) = await mgr.removeItem(at: 0)
        // Then: playerShouldStopが返り、削除曲が正しい・キューは空
        #expect(action == .playerShouldStop)
        #expect(removed?.id.rawValue == "A")
        #expect(mgr.items.isEmpty)
    }

    @Test("removeItem: 現在再生曲を削除すると playNewQueue")
    func testRemoveItemCurrent() async {
        // Given: 3曲のうちB(1)が再生中
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C")],
            startAt: 1
        )
        // When: B(1)を削除
        let (action, _) = await mgr.removeItem(at: 1)
        // Then: playNewQueueが返り、キュー・indexが更新
        #expect(action == .playNewQueue)
        #expect(mgr.items.map(\.id.rawValue) == ["A","C"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("removeItem: 範囲外のインデックスなら noAction で何も呼ばれない")
    func testRemoveItemOutOfBounds() async {
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        
        let adapter   = PlayerControllableMock()
        let queueMock = QueueManagingMock()
        queueMock.items = [A, B, C]
        queueMock.currentIndex = 0
        
        let context = AppDataStore.shared.container.mainContext
        let repo = PlayerStateRepository(context: context)
        let historyRepo = HistoryRepository(context: context)
        let service = MusicPlayerServiceImpl(
            rateManager: PlaybackRateManagerImpl(repo: repo),
            persistenceService: PlayerPersistenceServiceImpl(playerStateRepo: repo, historyRepo: historyRepo),
            historyManager: PlayHistoryManagerImpl(historyRepo: historyRepo),
            artworkService: ArtworkCacheServiceImpl(),
            playerAdapter: adapter,
            queueManager:  queueMock
        )
        
        // 4) 前後のコール数をキャプチャ
        let beforeSet  = adapter.setQueueDescriptors.count
        let beforeStop = adapter.stopCount
        
        // — 実行 —
        await service.removeItem(at: 5)   // 範囲外
        
        // — 検証 —
        #expect(adapter.setQueueDescriptors.count == beforeSet,
                "範囲外なら setQueue(with:) が呼ばれない")
        #expect(adapter.stopCount == beforeStop,
                "範囲外なら stop() も呼ばれない")
    }


    @Test("insertNext: 空キューに追加すると playNewQueue")
    func testInsertNextEmpty() async {
        // Given: 空のキュー
        let mgr = MusicQueueManager()
        // When: 1曲追加
        let (action, _) = await mgr.insertNext(makeDummySong(id: "X"))
        // Then: playNewQueueが返り、キューに1曲・index=0
        #expect(action == .playNewQueue)
        #expect(mgr.items.count == 1)
        #expect(mgr.currentIndex == 0)
    }
    
    @Test("playNextAndPlay: キュー内の曲を移動して再生する")
    func testPlayNextAndPlayWhenSongInQueue() async {
        // Given
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        sut.queueMock.items = [A, B, C]
        sut.queueMock.currentIndex = 1
        
        // When
        await sut.service.playNextAndPlay(B)
        
        // Then: QueueManagingMock にセットされたキューと index を検証
        #expect(sut.queueMock.items.map(\.id.rawValue) == ["A", "C", "B"])
        #expect(sut.queueMock.currentIndex == 2)
        // PlayerControllableMock の呼び出しも検証
        #expect(sut.adapter.setQueueDescriptors.count == 1,
                "1回 setQueue(with:) が呼ばれる")
        #expect(sut.adapter.playCount == 1,
                "1回 play() が呼ばれる")
    }
    
    @Test("playNextAndPlay: キュー外の曲を挿入して再生する")
    func testPlayNextAndPlayWhenSongNotInQueue() async {
        // Given
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        let D = makeDummySong(id: "D")
        sut.queueMock.items = [A, B, C]
        sut.queueMock.currentIndex = 0
        
        // When
        await sut.service.playNextAndPlay(D)
        
        // Then: QueueManagingMock にセットされたキューと index を検証
        #expect(sut.queueMock.items.map(\.id.rawValue) == ["A", "D", "B", "C"])
        #expect(sut.queueMock.currentIndex == 1)
        #expect(sut.adapter.setQueueDescriptors.count == 1,
                "1回 setQueue(with:) が呼ばれる")
        #expect(sut.adapter.playCount == 1,
                "1回 play() が呼ばれる")
    }
    
    @Test("advanceToNextTrack: 次の曲がない場合は何もしないこと")
    func testAdvanceOutOfRange() async {
        // Given: 1曲だけのキュー
        let mgr = MusicQueueManager()
        await mgr.setQueue([makeDummySong(id: "A")], startAt: 0)
        // When: advanceToNextTrackを呼ぶ
        let advanced = await mgr.advanceToNextTrack()
        // Then: 進まず、currentIndexも変化なし
        #expect(!advanced)
        #expect(mgr.currentIndex == 0)
    }

    @Test("advanceToNextTrack: 次の曲がある場合は進むこと")
    func testAdvanceSuccess() async {
        // Given: 2曲、index=0
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"),
             makeDummySong(id: "B")],
            startAt: 0
        )
        // When: advanceToNextTrackを呼ぶ
        let advanced = await mgr.advanceToNextTrack()
        // Then: 進み、currentIndex=1
        #expect(advanced)
        #expect(mgr.currentIndex == 1)
    }

    @Test("regressToPreviousTrack: 前の曲がない場合は何もしないこと")
    func testRegressOutOfRange() async {
        // Given: 2曲、index=0
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"),
             makeDummySong(id: "B")],
            startAt: 0
        )
        // When: regressToPreviousTrackを呼ぶ
        let regressed = await mgr.regressToPreviousTrack()
        // Then: 戻らず、currentIndexも変化なし
        #expect(!regressed)
        #expect(mgr.currentIndex == 0)
    }

    @Test("regressToPreviousTrack: 前の曲がある場合は戻ること")
    func testRegressSuccess() async {
        // Given: 2曲、index=1
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"),
             makeDummySong(id: "B")],
            startAt: 1
        )
        // When: regressToPreviousTrackを呼ぶ
        let regressed = await mgr.regressToPreviousTrack()
        // Then: 戻り、currentIndex=0
        #expect(regressed)
        #expect(mgr.currentIndex == 0)
    }

    @Test("songsForPlayerQueueDescriptor: キューがからの場合は空配列を返すこと")
    func testSongsForPlayerQueueDescriptorEmpty() async {
        // Given: 空のキュー
        let mgr = MusicQueueManager()
        // When: songsForPlayerQueueDescriptorを呼ぶ
        let list = await mgr.songsForPlayerQueueDescriptor()
        // Then: 空配列が返る
        #expect(list.isEmpty)
    }

    @Test("songsForPlayerQueueDescriptor: currentIndex以降の配列生成")
    func testSongsForPlayerQueueDescriptor() async {
        // Given: 3曲、index=1
        let mgr = MusicQueueManager()
        await mgr.setQueue(
            [makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C")],
            startAt: 1
        )
        // When: songsForPlayerQueueDescriptorを呼ぶ
        let list = await mgr.songsForPlayerQueueDescriptor()
        // Then: indexから末尾までの配列が返る（ローテーションなし）
        #expect(list.map(\.id.rawValue) == ["B","C"])
    }
}

// MARK: - MusicPlayerServiceImpl Tests
@Suite
@MainActor
struct MusicPlayerServiceImplTests {
    @Test("setQueue: currentTime=0・再生中スナップショットが出ること")
    func testSetQueue() async {
        // Given: SUTを生成し、2曲の配列を用意
        let sut = SUT.make()
        let songs = [ makeDummySong(id: "1"), makeDummySong(id: "2") ]
        // When: setQueueを呼ぶ
        await sut.service.setQueue(songs: songs, startAt: 1)
        // Then: queueMock.setQueueArgsに値が入り、currentTime=0、isPlaying=true
        #expect(sut.queueMock.setQueueArgs.last != nil, "setQueueArgs に要素が追加されている")
        #expect(sut.queueMock.setQueueArgs.last! == (songs, 1),
                "最後にセットされた引数が (songs, 1) である")
        #expect(sut.service.snapshot.currentTime == 0, "再生位置は0")
        #expect(sut.service.snapshot.isPlaying == true, "自動的に再生状態になる")
    }

    @Test("setQueue: musicPlayerQueue/nowPlayingIndex が同期していること")
    func testSetQueuePropertiesSync() async {
        // Given: SUTを生成し、2曲配列を用意
        let sut = SUT.make()
        let songs = [makeDummySong(id: "1"), makeDummySong(id: "2")]
        // When: setQueueを呼ぶ
        await sut.service.setQueue(songs: songs, startAt: 1)
        // Then: musicPlayerQueueとnowPlayingIndexが期待通り
        #expect(sut.service.musicPlayerQueue == songs)
        #expect(sut.service.nowPlayingIndex == 1)
    }

    @Test("play: isPlaying == true のスナップショット")
    func testPlay() async {
        // Given: SUT生成し、1曲セット
        let sut = SUT.make()
        await sut.service.setQueue(songs: [ makeDummySong(id: "1") ], startAt: 0)
        // When: playを呼ぶ
        await sut.service.play()
        // Then: isPlaying=trueのスナップショット
        #expect(sut.service.snapshot.isPlaying == true, "再生状態になる")
    }

    @Test("pause: isPlaying == false のスナップショット")
    func testPause() async {
        // Given: SUT生成し、1曲セットしてplay
        let sut = SUT.make()
        await sut.service.setQueue(songs: [ makeDummySong(id: "1") ], startAt: 0)
        await sut.service.play()
        // When: pauseを呼ぶ
        await sut.service.pause()
        // Then: isPlaying=falseのスナップショット
        #expect(sut.service.snapshot.isPlaying == false, "停止状態になる")
    }

    @Test("insertNext: 空キューに対して曲を追加すると再生が開始されること")
    func testInsertNextEmptyStartsPlayback() async {
        // Given: 空キュー状態のSUT
        let sut = SUT.make()
        let newSong = makeDummySong(id: "X")
        let beforeSet = sut.adapter.setQueueDescriptors.count
        let beforePlay = sut.adapter.playCount
        // When: insertNextで曲追加
        await sut.service.insertNext(newSong)
        // Then: setQueueDescriptors/ playCount が増加
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet + 1)
        #expect(sut.adapter.playCount == beforePlay + 1)
    }

    @Test("insertNext: 非空キューに割り込んで追加すると adapter.prepend が呼ばれること")
    func testInsertNextNonEmpty() async {
        // Given: 1曲セット済みのSUT
        let sut = SUT.make()
        let first = makeDummySong(id: "A")
        await sut.service.setQueue(songs: [ first ], startAt: 0)
        let newSong = makeDummySong(id: "B")
        let before = sut.adapter.prependDescriptors.count
        // When: insertNextで曲追加
        await sut.service.insertNext(newSong)
        // Then: prependDescriptorsが増加
        #expect(sut.adapter.prependDescriptors.count == before + 1, "adapter.prepend が呼ばれる")
    }

    @Test("seek: 負の値をシークすると0にクランプされること")
    func testSeekNegativeClampsToZero() async {
        // Given: SUTを生成
        let sut = SUT.make()
        // When: seekを-10で呼ぶ
        await sut.service.seek(to: -10)
        // Then: seekArgsの最後が0
        #expect(sut.adapter.seekArgs.last == 0)
    }

    @Test("seek: adapter.seekArgs に反映されること")
    func testSeek() async {
        // Given: SUTを生成し、duration=5の曲をセット
        let sut = SUT.make()
        let song = makeDummySong(id: "1", duration: 5)
        await sut.service.setQueue(songs: [ song ], startAt: 0)
        // When: seekを10で呼ぶ
        await sut.service.seek(to: 10)
        // Then: seekArgsの最後が5（durationにクランプ）
        #expect(sut.adapter.seekArgs.last == 5, "duration=5 なので 5 にクランプされること")
    }

    @Test("seek: 曲終端近くでシークしたときdurationまでクランプされること")
    func testSeekNearEndClampsToDuration() async {
        // Given: duration=100の曲
        let sut = SUT.make()
        let song = makeDummySong(id: "1", duration: 100)
        await sut.service.setQueue(songs: [song], startAt: 0)
        // When: seekを150で呼ぶ
        await sut.service.seek(to: 150)
        // Then: seekArgsの最後が100
        #expect(sut.adapter.seekArgs.last == 100)
    }

    @Test("setSessionRate: rate が snapshot に反映されること")
    func testSetSessionRate() async {
        // Given: SUT生成・1曲セット
        let sut = SUT.make()
        await sut.service.setQueue(songs: [ makeDummySong(id: "1") ], startAt: 0)
        // When: setSessionRateを1.5で呼ぶ
        await sut.service.setSessionRate(1.5)
        // Then: snapshot.rateが1.5
        #expect(sut.service.snapshot.rate == 1.5, "レートが1.5になる")
    }

    @Test("setSessionRate: 範囲外のレートは最小値に補正されること")
    func testSetSessionRateClampLower() async {
        // Given: SUT生成・1曲セット
        let sut = SUT.make()
        await sut.service.setQueue(songs: [makeDummySong(id: "1")], startAt: 0)
        // When: setSessionRateを0.1で呼ぶ
        await sut.service.setSessionRate(0.1)
        // Then: snapshot.rateが最小値
        #expect(sut.service.snapshot.rate == Constants.MusicPlayer.minPlaybackRate)
    }

    @Test("setSessionRate: 範囲外のレートは最大値に補正されること")
    func testSetSessionRateClampUpper() async {
        // Given: SUT生成・1曲セット
        let sut = SUT.make()
        await sut.service.setQueue(songs: [makeDummySong(id: "1")], startAt: 0)
        // When: setSessionRateを99.9で呼ぶ
        await sut.service.setSessionRate(99.9)
        // Then: snapshot.rateが最大値
        #expect(sut.service.snapshot.rate == Constants.MusicPlayer.maxPlaybackRate)
    }

    @Test("next: .playNewQueueでadapter.setQueueが呼ばれること")
    func testNextNormal() async {
        // Given: 2曲セット済み、index=0
        let sut = SUT.make()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        await sut.service.setQueue(songs: songs, startAt: 0)
        let before = sut.adapter.setQueueDescriptors.count
        // When: nextを呼ぶ
        await sut.service.next()
        // Then: setQueueDescriptorsが1増える
        #expect(sut.adapter.setQueueDescriptors.count == before + 1, "adapter.setQueue が呼ばれる")
    }

    @Test("next: 最後の曲で next() を呼んでも何もしないこと")
    func testNextAtEndNoOp() async {
        // Given: 2曲セット、indexは末尾
        let sut = SUT.make()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        await sut.service.setQueue(songs: songs, startAt: songs.count - 1)
        let before = sut.adapter.setQueueDescriptors.count
        // When: nextを呼ぶ
        await sut.service.next()
        // Then: setQueueDescriptorsは変化しない
        #expect(sut.adapter.setQueueDescriptors.count == before, "末端では何もしない")
    }

    @Test("previous: 最初の曲で previous() を呼んでも何もしないこと")
    func testPreviousAtStartNoOp() async {
        // Given: 2曲セット、index=0
        let sut = SUT.make()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        await sut.service.setQueue(songs: songs, startAt: 0)
        let before = sut.adapter.setQueueDescriptors.count
        // When: previousを呼ぶ
        await sut.service.previous()
        // Then: setQueueDescriptorsは変化しない
        #expect(sut.adapter.setQueueDescriptors.count == before, "先頭では何もしない")
    }

    @Test("previous: .playNewQueueでadapter.setQueueが呼ばれること")
    func testPreviousNormal() async {
        // Given: 2曲セット、index=1
        let sut = SUT.make()
        let songs = [ makeDummySong(id: "A"), makeDummySong(id: "B") ]
        await sut.service.setQueue(songs: songs, startAt: 1)
        let before = sut.adapter.setQueueDescriptors.count
        // When: previousを呼ぶ
        await sut.service.previous()
        // Then: setQueueDescriptorsが1増える
        #expect(sut.adapter.setQueueDescriptors.count == before + 1, "adapter.setQueue が呼ばれる")
    }

    @Test("playNow: 指定した曲のみで即座に再生開始されること")
    func testPlayNow() async {
        // Given: 別の曲でキューをセット
        let sut = SUT.make()
        let initial = makeDummySong(id: "X")
        await sut.service.setQueue(songs: [ initial ], startAt: 0)
        let target = makeDummySong(id: "Y")
        let beforeSet = sut.adapter.setQueueDescriptors.count
        let beforePlay = sut.adapter.playCount
        // When: playNowをtargetで呼ぶ
        await sut.service.playNow(target)
        // Then: setQueueDescriptorsとplayCountが1増加
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet + 1, "adapter.setQueue が呼ばれる")
        #expect(sut.adapter.playCount == beforePlay + 1, "play() が呼ばれる")
    }

    @Test("playNow: 既存キューを破棄して指定曲のみ再生されること")
    func testPlayNowReplacesQueue() async {
        // Given: 既存キューにA
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        await sut.service.setQueue(songs: [A], startAt: 0)
        let beforePlay = sut.adapter.playCount
        let B = makeDummySong(id: "B")
        // When: playNowをBで呼ぶ
        await sut.service.playNow(B)
        // Then: musicPlayerQueueとnowPlayingIndexがBのみ・0になりplayCountが1増
        #expect(sut.service.musicPlayerQueue == [B])
        #expect(sut.service.nowPlayingIndex == 0)
        #expect(sut.adapter.playCount == beforePlay + 1)
    }

    @Test("removeItem: 非再生中の曲を削除すると、trackChanged 後に adapter.setQueue + seek が呼ばれる")
    func testRemoveItemNonCurrentWithTrackChanged() async {
        //-- Setup
        let sut   = SUT.make()
        let A     = makeDummySong(id: "A")
        let B     = makeDummySong(id: "B")
        let C     = makeDummySong(id: "C")
        // A(0) を再生中としてセット
        await sut.service.setQueue(songs: [A, B, C], startAt: 0)
        
        let beforeSet  = sut.adapter.setQueueDescriptors.count
        let beforeSeek = sut.adapter.seekArgs.count
        
        //-- 実行：非再生中の曲を削除（フラグだけ立つ）
        await sut.service.removeItem(at: 2)
        
        //-- trackChanged() をシミュレートするための通知発火
        // 1) adapterの indexOfNowPlayingItem が queueMock.currentIndex と一致するようにする
        sut.adapter.indexOfNowPlayingItem = sut.queueMock.currentIndex
        // 2) 曲変更通知をポスト
        NotificationCenter.default.post(
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil
        )
        // 非同期後処理が回るのを少しだけ待機
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        //-- 検証
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet + 1,
                "非再生中 remove 後の trackChanged で adapter.setQueue(with:) が呼ばれる")
        #expect(sut.adapter.seekArgs.last == 0,
                "seek(0) が呼ばれる（現在位置0を維持）")
    }

    @Test("removeItem: 再生中の曲を削除すると再生開始されること")
    func testRemoveItemCurrent() async {
        // Given: 3曲セット、B(1)が再生中
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        await sut.service.setQueue(songs: [A,B,C], startAt: 1)
        let beforeSet = sut.adapter.setQueueDescriptors.count
        let beforePlay = sut.adapter.playCount
        // When: B(1)を削除
        await sut.service.removeItem(at: 1)
        // Then: setQueueDescriptors/ playCount が1増加
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet + 1, "adapter.setQueue が呼ばれる")
        #expect(sut.adapter.playCount == beforePlay + 1, "play() が呼ばれる")
    }

    @Test("removeItem: 唯一の曲を削除すると停止されること")
    func testRemoveItemSingleStops() async {
        // Given: 唯一の曲Zでキューをセット
        let sut = SUT.make()
        let only = makeDummySong(id: "Z")
        await sut.service.setQueue(songs: [ only ], startAt: 0)
        let beforeStop = sut.adapter.stopCount
        // When: 唯一の曲を削除
        await sut.service.removeItem(at: 0)
        // Then: stopCountが1増加
        #expect(sut.adapter.stopCount == beforeStop + 1, "stop() が呼ばれる")
    }

    @Test("trackChanged: trackChanged通知で履歴が追加されること")
    func testTrackChangedHistory() async {
        // Given: 1曲セット済みのadapter, queue, service
        let adapter = PlayerControllableMock()
        let queue   = QueueManagingMock()
        let context = AppDataStore.shared.container.mainContext
        let repo = PlayerStateRepository(context: context)
        let historyRepo = HistoryRepository(context: context)
        let service = MusicPlayerServiceImpl(
            rateManager: PlaybackRateManagerImpl(repo: repo),
            persistenceService: PlayerPersistenceServiceImpl(playerStateRepo: repo, historyRepo: historyRepo),
            historyManager: PlayHistoryManagerImpl(historyRepo: historyRepo),
            artworkService: ArtworkCacheServiceImpl(),
            playerAdapter: adapter,
            queueManager: queue
        )
        let testSong = makeDummySong(id: "TEST")
        queue.items = [testSong]
        queue.currentIndex = 0
        adapter.indexOfNowPlayingItem = 0
        // When: NowPlayingItemDidChange通知を送信
        NotificationCenter.default.post(
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: MPMusicPlayerController.applicationQueuePlayer
        )
        // 非同期ハンドリングのため少し待機
        try! await Task.sleep(nanoseconds: 100_000_000)
        // Then: playHistory.countが1になる
        #expect(service.playHistory.count == 1, "履歴が1件追加される")
    }

    @Test("trackChanged: moveItem 後に trackChanged 発火で実際に setQueue/seek が呼ばれる")
    func testMoveThenTrackChanged() async {
        let sut = SUT.make()
        let A = makeDummySong(id: "A")
        let B = makeDummySong(id: "B")
        let C = makeDummySong(id: "C")
        // A(0) 再生中
        await sut.service.setQueue(songs: [A,B,C], startAt: 0)
        let beforeSet = sut.adapter.setQueueDescriptors.count
        // C(2) → 1 に移動
        await sut.service.moveItem(from: 2, to: 1)
        // nowPlayingItem／indexOfNowPlayingItem を合わせておく
        sut.adapter.indexOfNowPlayingItem = 0
        // 曲変更通知をポスト
        NotificationCenter.default.post(
        name: .MPMusicPlayerControllerNowPlayingItemDidChange,
        object: nil
        )
        // 少し待つか、async で待機
        try? await Task.sleep(nanoseconds: 100_000_000)
        // adapter.setQueue(with:) が１回増えている
        #expect(sut.adapter.setQueueDescriptors.count == beforeSet + 1)
        // seek(0) も呼ばれている
        #expect(sut.adapter.seekArgs.last == 0)
    }

    @Test("toggleShuffle: アプリ側でキューがシャッフルされること")
    func testToggleShuffle() async {
        let sut = SUT.make()
        let songs = [makeDummySong(id: "A"), makeDummySong(id: "B"), makeDummySong(id: "C")]
        await sut.service.setQueue(songs: songs, startAt: 0)
        // 初期状態はoff
        #expect(sut.adapter.shuffleMode == .off)
        #expect(!sut.service.isShuffled)
        // トグル ON
        await sut.service.toggleShuffle()
        #expect(sut.adapter.shuffleMode == .off, "player.shuffleMode は常に .off（アプリ側制御）")
        #expect(sut.service.isShuffled, "isShuffled が true になる")
        // 現在の曲（A）が先頭に固定されている
        #expect(sut.service.musicPlayerQueue.first?.id.rawValue == "A",
                "再生中の曲がシャッフル後も先頭に固定")
        #expect(sut.service.musicPlayerQueue.count == 3, "曲数が維持される")
        // トグル OFF
        await sut.service.toggleShuffle()
        #expect(sut.adapter.shuffleMode == .off, "player.shuffleMode は .off のまま")
        #expect(!sut.service.isShuffled, "isShuffled が false に戻る")
        // 元の順序に復元される
        #expect(sut.service.musicPlayerQueue.map(\.id.rawValue) == ["A","B","C"],
                "元のキュー順が復元される")
    }
    
    @Test("cycleRepeatMode: none→all→one→none の順に切り替わること")
    func testCycleRepeatMode() async {
        let sut = SUT.make()
        // 初期状態は.none
        #expect(sut.adapter.repeatMode == .none)
        #expect(sut.service.repeatMode == .none)
        // none → all
        await sut.service.cycleRepeatMode()
        #expect(sut.adapter.repeatMode == .all,  "adapter.repeatMode が .all に")
        #expect(sut.service.repeatMode == .all,  "service.repeatMode が .all に")
        // all → one
        await sut.service.cycleRepeatMode()
        #expect(sut.adapter.repeatMode == .one,  "adapter.repeatMode が .one に")
        #expect(sut.service.repeatMode == .one,  "service.repeatMode が .one に")
        // one → none
        await sut.service.cycleRepeatMode()
        #expect(sut.adapter.repeatMode == .none, "adapter.repeatMode が .none に戻る")
        #expect(sut.service.repeatMode == .none, "service.repeatMode が .none に戻る")
    }
}

// MARK: - Characterization Tests (Phase 1-2)
/// 大きな責務分割前に重要な挙動を固定するテスト群
@Suite
@MainActor
struct CharacterizationTests {
    // MARK: 1. session rate 変更がプレーヤーに即反映される
    @Test("session rate 変更が adapter.playbackRate に即反映される")
    func testSessionRateReflectsInPlayer() async {
        let sut = SUT.make()
        await sut.service.setQueue(songs: [makeDummySong(id: "1")], startAt: 0)

        await sut.service.setSessionRate(2.0)

        #expect(sut.adapter.playbackRate == 2.0, "adapter の playbackRate が更新される")
        #expect(sut.service.snapshot.rate == 2.0, "snapshot.rate も即更新される")
    }

    // MARK: 2. default rate が SwiftData に永続化される
    @Test("default rate が repo に永続化される")
    func testDefaultRatePersistence() async throws {
        let sut = SUT.make()
        let newRate = 1.8

        try await sut.rateManager.setDefaultRate(newRate)

        let loaded = try sut.repo.load()
        #expect(loaded.playbackRate == newRate, "永続化されたレートが一致する")
        #expect(sut.rateManager.defaultRate == newRate, "メモリ上の defaultRate も一致する")
    }

    // MARK: 3. アプリ再起動後に default rate が復元される
    @Test("再起動シミュレーション: 永続化した rate が新 rateManager に復元される")
    func testDefaultRateRestoredOnRestart() async throws {
        let sut = SUT.make()
        let persistedRate = 2.5

        // default rate を永続化
        try await sut.rateManager.setDefaultRate(persistedRate)

        // 新しい rateManager を同じ repo から作成（再起動をシミュレーション）
        let newRateManager = PlaybackRateManagerImpl(repo: sut.repo)
        #expect(newRateManager.defaultRate == persistedRate,
                "新しい rateManager が永続化された rate を読み込む")
    }

    // MARK: 4. trackChanged 後の保存整合
    @Test("曲変更後に default rate で保存される（session rate ではない）")
    func testTrackChangedSavesDefaultRate() async throws {
        let sut = SUT.make()
        let songs = [makeDummySong(id: "CHAR_A"), makeDummySong(id: "CHAR_B")]
        await sut.service.setQueue(songs: songs, startAt: 0)

        // default rate を 1.5 に設定
        try await sut.rateManager.setDefaultRate(1.5)
        // session rate を 2.5 に設定（default とは異なる値）
        await sut.service.setSessionRate(2.5)

        // 次の曲に進む（updateSnapshot が走り、新曲検知で repo に保存される）
        await sut.service.next()

        // 保存されたレートは default rate (1.5) であること（session rate 2.5 ではない）
        let loaded = try sut.repo.load()
        #expect(loaded.playbackRate == 1.5,
                "永続化されるのは defaultRate であり sessionRate ではない")
    }

    // MARK: 5. Settings 画面からの変更が Player に反映される
    @Test("SettingsViewModel 経由の default rate 変更が session rate にも反映される")
    func testSettingsToPlayerPropagation() async throws {
        let sut = SUT.make()
        await sut.service.setQueue(songs: [makeDummySong(id: "1")], startAt: 0)

        // SettingsViewModel を作成（実際の DI と同じ構成）
        let settingsVM = SettingsViewModel(
            rateManager: sut.rateManager,
            playerService: sut.service
        )

        // Settings UI からレート変更
        settingsVM.updateDefaultRate(to: 1.8)

        // Task 内で非同期処理が走るためポーリングで完了を待機（最大2秒）
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if sut.adapter.playbackRate == 1.8 { break }
        }

        // default rate が永続化される
        #expect(sut.rateManager.defaultRate == 1.8, "defaultRate が更新される")
        // session rate にも反映される（Player 画面に即反映）
        #expect(sut.service.snapshot.rate == 1.8, "snapshot.rate にも反映される")
        #expect(sut.adapter.playbackRate == 1.8, "adapter.playbackRate にも反映される")
        // VM の表示値も更新される
        #expect(settingsVM.defaultRate == 1.8, "settingsVM.defaultRate も同期される")
    }
}