import Testing
import Foundation
import Combine
@testable import Night_Core_Player

@Suite("AllowanceEnforcer Tests")
@MainActor
struct AllowanceEnforcerTests {

    // MARK: - Helpers

    private static let base = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00+09:00")!

    @MainActor
    private final class EventRecorder {
        var received: [AllowanceEvent] = []
        private var cancellables: Set<AnyCancellable> = []

        init(events: AnyPublisher<AllowanceEvent, Never>) {
            events.sink { [weak self] in self?.received.append($0) }
                .store(in: &cancellables)
        }
    }

    private static func makeEnforcer(
        entitlement: PlaybackEntitlement = .free(remaining: Constants.Allowance.dailyFreeSeconds),
        isProEntitled: @escaping () -> Bool = { false }
    ) -> (enforcer: AllowanceEnforcerImpl, mock: AllowanceServiceMock, recorder: EventRecorder) {
        let mock = AllowanceServiceMock()
        mock.entitlementResult = entitlement
        let enforcer = AllowanceEnforcerImpl(
            allowanceService: mock,
            isProEntitled: isProEntitled
        )
        let recorder = EventRecorder(events: enforcer.events)
        return (enforcer, mock, recorder)
    }

    // MARK: - Tick / Consume

    @Test("tick: 等速再生では消費しない")
    func tickNormalRateDoesNotConsume() {
        // Given: 残高ありのEnforcer
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: 等速で2回tick
        enforcer.tick(isPlaying: true, rate: 1.0, now: t0)
        enforcer.tick(isPlaying: true, rate: 1.0, now: t0.addingTimeInterval(10))
        // Then: consumeは呼ばれない
        #expect(mock.consumeArgs.isEmpty)
    }

    @Test("tick: 倍速+再生中は前回tickからの経過秒を消費する")
    func tickNightcoreConsumesElapsedSeconds() {
        // Given: 残高ありのEnforcer
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: 初回tick（計測起点）→ 10秒後にtick
        enforcer.tick(isPlaying: true, rate: 1.5, now: t0)
        enforcer.tick(isPlaying: true, rate: 1.5, now: t0.addingTimeInterval(10))
        // Then: 2回目のtickで10秒消費。初回は起点のみで消費しない
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 10)
    }

    @Test("tick: 一時停止中は消費しない")
    func tickPausedDoesNotConsume() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: false, rate: 2.0, now: t0)
        enforcer.tick(isPlaying: false, rate: 2.0, now: t0.addingTimeInterval(30))
        #expect(mock.consumeArgs.isEmpty)
    }

    @Test("tick: 前回tickから60秒超の間隔は60秒にクランプされる")
    func tickClampsLongGapToSixtySeconds() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: バックグラウンド放置を想定した1時間後のtick
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(3600))
        // Then: 消費は60秒にクランプされる
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 60)
    }

    @Test("tick: トライアル中は枯渇扱いしない")
    func tickTrialIsNotExhausted() {
        let (enforcer, _, recorder) = Self.makeEnforcer(
            entitlement: .trial(endsAt: Self.base.addingTimeInterval(86400))
        )
        enforcer.tick(isPlaying: true, rate: 2.0, now: Self.base)
        #expect(!enforcer.isExhausted)
        #expect(recorder.received.isEmpty)
    }

    @Test("Pro有効時はtickで消費されずアームもされない")
    func tickWithProDoesNotConsumeOrArm() {
        // Given: 残高枯渇だがPro有効
        let isPro = true
        let (enforcer, mock, recorder) = Self.makeEnforcer(
            entitlement: .exhausted,
            isProEntitled: { isPro }
        )
        let t0 = Self.base
        // When: 倍速+再生中で複数回tick
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(10))
        // Then: 消費も停止予約のアームも行わない
        #expect(mock.consumeArgs.isEmpty)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received.isEmpty)
    }

    @Test("Pro有効化で既存の停止予約がクリアされる")
    func proActivationClearsPendingStop() {
        // Given: 枯渇+倍速の非Pro状態。2回目のtickで経過秒が消費され、アーム済みになる
        var isPro = false
        let (enforcer, mock, recorder) = Self.makeEnforcer(
            entitlement: .exhausted,
            isProEntitled: { isPro }
        )
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(10))
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(mock.consumeArgs.first?.seconds == 10)
        let consumeCountBeforePro = mock.consumeArgs.count
        // When: Proを購入して有効化
        isPro = true
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(20))
        // Then: 停止予約が解除され、Pro化後のtickでは消費も再アームもされない
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(mock.consumeArgs.count == consumeCountBeforePro)
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    // MARK: - Exhaustion / Events

    @Test("枯渇検知でexhaustedPendingSongEndを発行し、曲境界停止対象になる")
    func exhaustionSetsBoundaryStop() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        // When: 枯渇状態でtick
        enforcer.tick(isPlaying: true, rate: 2.0, now: Self.base)
        // Then
        #expect(enforcer.isExhausted)
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("exhaustedPendingSongEndは二重発行されない")
    func exhaustedEventFiresOnlyOnce() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        let t0 = Self.base
        // When: 枯渇したまま複数回tick
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(10))
        enforcer.tick(isPlaying: false, rate: 1.0, now: t0.addingTimeInterval(20))
        // Then: イベントは1回だけ
        #expect(recorder.received == [.exhaustedPendingSongEnd])
        #expect(enforcer.shouldStopAtSongBoundary())
    }

    @Test("残高回復するとshouldStopAtSongBoundaryがfalseに戻る")
    func recoveryResetsBoundaryStop() {
        let (enforcer, mock, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        // When: リワード広告等で残高が回復する
        mock.entitlementResult = .free(remaining: Constants.Allowance.rewardSeconds)
        enforcer.tick(isPlaying: false, rate: 1.0, now: t0.addingTimeInterval(10))
        // Then: 停止対象が解除され、枯渇イベントは再発行されない
        #expect(!enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("markStoppedAtSongEndで停止予約がクリアされる")
    func markStoppedClearsPendingStop() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        enforcer.tick(isPlaying: true, rate: 2.0, now: Self.base)
        #expect(enforcer.shouldStopAtSongBoundary())
        // When: 曲境界での停止完了を通知
        enforcer.markStoppedAtSongEnd()
        // Then: 停止イベントが出て、停止予約は解除される
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [.exhaustedPendingSongEnd, .stoppedAtSongEnd])
    }

    @Test("枯渇中でも等速ではアームされない（イベント発行なし）")
    func exhaustionDoesNotArmAtNormalRate() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        // When: 枯渇したまま等速再生をtick
        enforcer.tick(isPlaying: true, rate: 1.0, now: Self.base)
        enforcer.tick(isPlaying: true, rate: 1.0, now: Self.base.addingTimeInterval(10))
        // Then: 素のApple Music再生は止めないためアームしない
        #expect(enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received.isEmpty)
    }

    @Test("枯渇後に等速へ戻ると停止予約が解除される")
    func returningToNormalRateClearsPendingStop() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        #expect(enforcer.shouldStopAtSongBoundary())
        // When: 倍速のまま枯渇検知後、ユーザーが等速へ戻して再生継続
        enforcer.tick(isPlaying: true, rate: 1.0, now: t0.addingTimeInterval(10))
        // Then: 停止予約のみ解除され、残高は枯渇したまま
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(enforcer.isExhausted)
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("停止後に再度倍速へ上げると再アームされ、exhaustedPendingSongEndが2度目に発行される")
    func rearmsWhenNightcoreResumesAfterStop() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0)
        enforcer.markStoppedAtSongEnd()
        #expect(!enforcer.shouldStopAtSongBoundary())
        // When: 手動で再度倍速へ上げて再生
        enforcer.tick(isPlaying: true, rate: 2.0, now: t0.addingTimeInterval(10))
        // Then: 再アームされ、イベントは2回目に発行される
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [
            .exhaustedPendingSongEnd,
            .stoppedAtSongEnd,
            .exhaustedPendingSongEnd
        ])
    }

    @Test("isExhaustedは残高状態を表し、停止予約とは独立している")
    func isExhaustedIndependentFromPendingStop() {
        let (enforcer, _, _) = Self.makeEnforcer(entitlement: .exhausted)
        enforcer.tick(isPlaying: true, rate: 2.0, now: Self.base)
        // When: 曲境界での停止を完了させる
        enforcer.markStoppedAtSongEnd()
        // Then: 残高は枯渇のまま、停止予約だけが解除される
        #expect(enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
    }
}
