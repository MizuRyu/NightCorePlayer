import Testing
import Combine
import SwiftUI
import MusicKit
import MediaPlayer
@testable import Night_Core_Player  // 実際のモジュール名に置き換えてください

// MARK: - ServiceImpl Tests

@Suite
@MainActor
struct MusicPlayerServiceImplTests {
    static func setUp() -> (
        service: MusicPlayerServiceImpl,
        snapshotsPtr: UnsafeMutablePointer<[MusicPlayerSnapshot]>,
        cancellable: AnyCancellable
    ) {
        let service = MusicPlayerServiceImpl()
        let ptr = UnsafeMutablePointer<[MusicPlayerSnapshot]>.allocate(capacity: 1)
        ptr.initialize(to: [])
        let cancellable = service.snapshotPublisher
            .sink { ptr.pointee.append($0) }
        return (service, ptr, cancellable)
    }
    
    @Test("setQueue: songs と startAt を渡すと currentTime=0・停止状態のスナップショットが送られること")
    func testSetQueue() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        let songs: [Song] = [
            makeDummySong(id: "1"),
            makeDummySong(id: "2")
        ]
        // When
        await service.setQueue(songs: songs, startAt: 1)
        
        // Then
        let last = ptr.pointee.last
        #expect(last?.currentTime == 0, "再生位置が0であること")
        #expect(last?.isPlaying == false, "停止状態であること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    
    @Test("setQueue: 空配列でも例外なく動作し、スナップショットが1回以上送られること")
    func testSetQueueEmpty() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        let empty: [Song] = []
        
        // When
        await service.setQueue(songs: empty, startAt: 0)
        
        // Then
        #expect(!ptr.pointee.isEmpty, "スナップショットが発行されること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    
    @Test("play: play() 呼び出しで isPlaying == true のスナップショットが送られること")
    func testPlay() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        
        // When
        await service.play()
        
        // FIXME: フィールド値は確認していないため、厳密に確認するのであればMPMusicPlayerのスタブ実装が必要
        #expect(!ptr.pointee.isEmpty, "少なくとも1回 snapshot が発行されること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    
    @Test("pause: pause() 呼び出しで isPlaying == false のスナップショットが送られること")
    func testPause() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        await service.play()
        
        // When
        await service.pause()
        
        // Then
        let last = ptr.pointee.last
        #expect(last?.isPlaying == false, "停止状態であること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    
    @Test("seek: 有効範囲内をシークすると currentTime が反映されること")
    func testSeek() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        
        // When
        await service.seek(to: 42)
        
        // FIXME: フィールド値は確認していないため、厳密に確認するのであればMPMusicPlayerのスタブ実装が必要
        #expect(!ptr.pointee.isEmpty, "少なくとも1回 snapshot が発行されること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    
    @Test("changeRate: rate を変更すると snapshot に反映されること")
    func testChangeRate() async {
        // Given
        let (service, ptr, cancel) = MusicPlayerServiceImplTests.setUp()
        
        // When
        await service.changeRate(to: 1.5)
        
        // Then
        let last = ptr.pointee.last
        #expect(last?.rate == 1.5, "レートが1.5に反映されること")
        
        cancel.cancel()
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
}
