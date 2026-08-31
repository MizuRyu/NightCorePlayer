import Testing
import NightCoreDomain

/// キュー操作アルゴリズムの検証。要素は不透明に扱われるため Item == String で固定する
@Suite("MusicQueueManager Tests", .serialized)
@MainActor
struct MusicQueueManagerTests {

    @Test("setQueue: 空配列なら playerShouldStop & currentIndex=0")
    func setQueue_empty_stopsPlayer() async {
        let mgr = MusicQueueManager<String>()

        let action = await mgr.setQueue([], startAt: 5)

        #expect(action == .playerShouldStop)
        #expect(mgr.items.isEmpty)
        #expect(mgr.currentIndex == 0)
    }

    @Test("setQueue: startAt 下限を clamp すること")
    func setQueue_negativeStart_clampsToZero() async {
        let mgr = MusicQueueManager<String>()

        let action = await mgr.setQueue(["A", "B"], startAt: -1)

        #expect(action == .playNewQueue)
        #expect(mgr.currentIndex == 0)
    }

    @Test("setQueue: startAt 上限を clamp すること")
    func setQueue_hugeStart_clampsToLast() async {
        let mgr = MusicQueueManager<String>()

        let action = await mgr.setQueue(["A", "B"], startAt: 999)

        #expect(action == .playNewQueue)
        #expect(mgr.currentIndex == 1)
    }

    @Test("currentSong: currentIndex が範囲外なら nil")
    func currentSong_indexOutOfRange_returnsNil() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B"], startAt: 0)

        mgr.currentIndex = 5

        #expect(mgr.currentSong == nil)
    }

    @Test("moveItem: src==dst の場合は noAction")
    func moveItem_sameIndex_noAction() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let action = await mgr.moveItem(from: 1, to: 1)

        #expect(action == .noAction)
        #expect(mgr.items == ["A", "B", "C"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("moveItem: 範囲外のインデックスなら noAction")
    func moveItem_outOfBounds_noAction() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let action = await mgr.moveItem(from: 0, to: 9)

        #expect(action == .noAction)
        #expect(mgr.items == ["A", "B", "C"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("moveItem: 楽曲を前方に移動できること")
    func moveItem_forward_reordersAndFollowsCurrent() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let action = await mgr.moveItem(from: 1, to: 0)

        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items == ["B", "A", "C"])
        #expect(mgr.currentIndex == 0, "再生中の曲を動かすと currentIndex も追従する")
    }

    @Test("moveItem: 楽曲を後方に移動できること")
    func moveItem_backward_reordersAndFollowsCurrent() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 0)

        let action = await mgr.moveItem(from: 0, to: 2)

        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items == ["B", "C", "A"])
        #expect(mgr.currentIndex == 2, "再生中の曲を動かすと currentIndex も追従する")
    }

    @Test("moveItem: 再生中より前の曲を後ろへ動かすと currentIndex が繰り上がること")
    func moveItem_fromBeforeCurrentToAfter_decrementsCurrentIndex() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C", "D"], startAt: 2)

        let action = await mgr.moveItem(from: 0, to: 3)

        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items == ["B", "C", "D", "A"])
        #expect(mgr.currentIndex == 1, "再生中の C を指し続ける")
    }

    @Test("moveItem: 再生中より後ろの曲を前へ動かすと currentIndex が繰り下がること")
    func moveItem_fromAfterCurrentToBefore_incrementsCurrentIndex() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C", "D"], startAt: 1)

        let action = await mgr.moveItem(from: 3, to: 0)

        #expect(action == .updatePlayerQueueOnly)
        #expect(mgr.items == ["D", "A", "B", "C"])
        #expect(mgr.currentIndex == 2, "再生中の B を指し続ける")
    }

    @Test("removeItem: 1曲のみなら playerShouldStop")
    func removeItem_lastRemaining_stopsPlayer() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A"], startAt: 0)

        let (action, removed) = await mgr.removeItem(at: 0)

        #expect(action == .playerShouldStop)
        #expect(removed == "A")
        #expect(mgr.items.isEmpty)
        #expect(mgr.currentIndex == 0)
    }

    @Test("removeItem: 現在再生曲を削除すると playNewQueue")
    func removeItem_current_playsNewQueue() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let (action, removed) = await mgr.removeItem(at: 1)

        #expect(action == .playNewQueue)
        #expect(removed == "B")
        #expect(mgr.items == ["A", "C"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("removeItem: 末尾の再生中曲を削除すると currentIndex が末尾に丸められること")
    func removeItem_currentAtTail_clampsCurrentIndex() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 2)

        let (action, _) = await mgr.removeItem(at: 2)

        #expect(action == .playNewQueue)
        #expect(mgr.items == ["A", "B"])
        #expect(mgr.currentIndex == 1)
    }

    @Test("removeItem: 再生中より前を削除すると currentIndex が繰り上がること")
    func removeItem_beforeCurrent_decrementsCurrentIndex() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 2)

        let (action, removed) = await mgr.removeItem(at: 0)

        #expect(action == .updatePlayerQueueOnly)
        #expect(removed == "A")
        #expect(mgr.items == ["B", "C"])
        #expect(mgr.currentIndex == 1, "再生中の C を指し続ける")
    }

    @Test("removeItem: 再生中より後ろを削除しても currentIndex は変わらないこと")
    func removeItem_afterCurrent_keepsCurrentIndex() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 0)

        let (action, removed) = await mgr.removeItem(at: 2)

        #expect(action == .updatePlayerQueueOnly)
        #expect(removed == "C")
        #expect(mgr.items == ["A", "B"])
        #expect(mgr.currentIndex == 0)
    }

    @Test("removeItem: 範囲外のインデックスなら noAction")
    func removeItem_outOfBounds_noAction() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 0)

        let (action, removed) = await mgr.removeItem(at: 5)

        #expect(action == .noAction)
        #expect(removed == nil)
        #expect(mgr.items == ["A", "B", "C"])
    }

    @Test("insertNext: 空キューに追加すると playNewQueue")
    func insertNext_emptyQueue_playsNewQueue() async {
        let mgr = MusicQueueManager<String>()

        let (action, newIndex) = await mgr.insertNext("X")

        #expect(action == .playNewQueue)
        #expect(newIndex == 0)
        #expect(mgr.items == ["X"])
        #expect(mgr.currentIndex == 0)
    }

    @Test("insertNext: 再生中の次の位置へ挿入されること")
    func insertNext_nonEmptyQueue_insertsAfterCurrent() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let (action, newIndex) = await mgr.insertNext("X")

        #expect(action == .updatePlayerQueueOnly)
        #expect(newIndex == 2)
        #expect(mgr.items == ["A", "B", "X", "C"])
        #expect(mgr.currentIndex == 1, "再生位置は動かない")
    }

    @Test("insertNext: 末尾再生中なら末尾へ挿入されること")
    func insertNext_currentAtTail_appendsToEnd() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B"], startAt: 1)

        let (action, newIndex) = await mgr.insertNext("X")

        #expect(action == .updatePlayerQueueOnly)
        #expect(newIndex == 2)
        #expect(mgr.items == ["A", "B", "X"])
    }

    @Test("advanceToNextTrack: 次の曲がない場合は何もしないこと")
    func advanceToNextTrack_atTail_returnsFalse() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A"], startAt: 0)

        let advanced = await mgr.advanceToNextTrack()

        #expect(!advanced)
        #expect(mgr.currentIndex == 0)
    }

    @Test("advanceToNextTrack: 次の曲がある場合は進むこと")
    func advanceToNextTrack_hasNext_advances() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B"], startAt: 0)

        let advanced = await mgr.advanceToNextTrack()

        #expect(advanced)
        #expect(mgr.currentIndex == 1)
    }

    @Test("regressToPreviousTrack: 前の曲がない場合は何もしないこと")
    func regressToPreviousTrack_atHead_returnsFalse() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B"], startAt: 0)

        let regressed = await mgr.regressToPreviousTrack()

        #expect(!regressed)
        #expect(mgr.currentIndex == 0)
    }

    @Test("regressToPreviousTrack: 前の曲がある場合は戻ること")
    func regressToPreviousTrack_hasPrevious_regresses() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B"], startAt: 1)

        let regressed = await mgr.regressToPreviousTrack()

        #expect(regressed)
        #expect(mgr.currentIndex == 0)
    }

    @Test("songsForPlayerQueueDescriptor: キューが空の場合は空配列を返すこと")
    func songsForPlayerQueueDescriptor_empty_returnsEmpty() async {
        let mgr = MusicQueueManager<String>()

        let list = await mgr.songsForPlayerQueueDescriptor()

        #expect(list.isEmpty)
    }

    @Test("songsForPlayerQueueDescriptor: currentIndex以降の配列生成")
    func songsForPlayerQueueDescriptor_fromCurrentIndex_returnsSuffix() async {
        let mgr = MusicQueueManager<String>()
        await mgr.setQueue(["A", "B", "C"], startAt: 1)

        let list = await mgr.songsForPlayerQueueDescriptor()

        #expect(list == ["B", "C"], "indexから末尾まで(ローテーションなし)")
    }
}
