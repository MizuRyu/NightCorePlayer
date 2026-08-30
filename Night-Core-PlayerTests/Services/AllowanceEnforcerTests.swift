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

    /// 猶予が与えられる唯一の経路（倍速で鳴っている最中に残高が尽きる）を作る。
    /// 残高0の状態から倍速へ入れても猶予は付かないため、テストでもこの手順を踏む必要がある
    private static func exhaustWhileSpedUp(
        _ enforcer: AllowanceEnforcerImpl,
        _ mock: AllowanceServiceMock,
        songID: String = "S1",
        at time: Date
    ) {
        mock.entitlementResult = .free(remaining: 10)
        enforcer.tick(isPlaying: true, rate: 2.0, songID: songID, now: time)
        mock.entitlementResult = .exhausted
        enforcer.tick(isPlaying: true, rate: 2.0, songID: songID, now: time.addingTimeInterval(10))
    }

    // MARK: - Tick / Consume

    @Test("tick: 等速再生では消費しない")
    func tickNormalRateDoesNotConsume() {
        // Given: 残高ありのEnforcer
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: 等速で2回tick
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: t0)
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: t0.addingTimeInterval(10))
        // Then: consumeは呼ばれない
        #expect(mock.consumeArgs.isEmpty)
    }

    @Test("tick: 倍速+再生中は前回tickからの経過秒を消費する")
    func tickNightcoreConsumesElapsedSeconds() {
        // Given: 残高ありのEnforcer
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: 初回tick（計測起点）→ 10秒後にtick
        enforcer.tick(isPlaying: true, rate: 1.5, songID: "S1", now: t0)
        enforcer.tick(isPlaying: true, rate: 1.5, songID: "S1", now: t0.addingTimeInterval(10))
        // Then: 2回目のtickで10秒消費。初回は起点のみで消費しない
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 10)
    }

    @Test("tick: 一時停止中は消費しない")
    func tickPausedDoesNotConsume() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: false, rate: 2.0, songID: "S1", now: t0)
        enforcer.tick(isPlaying: false, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(30))
        #expect(mock.consumeArgs.isEmpty)
    }

    @Test("tick: 前回tickから60秒超の間隔は60秒にクランプされる")
    func tickClampsLongGapToSixtySeconds() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: バックグラウンド放置を想定した1時間後のtick
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(3600))
        // Then: 消費は60秒にクランプされる
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 60)
    }

    @Test("tick: トライアル中は枯渇扱いしない")
    func tickTrialIsNotExhausted() {
        let (enforcer, _, recorder) = Self.makeEnforcer(
            entitlement: .trial(endsAt: Self.base.addingTimeInterval(86400))
        )
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: Self.base)
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
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0)
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(10))
        // Then: 消費も停止予約のアームも行わない
        #expect(mock.consumeArgs.isEmpty)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received.isEmpty)
    }

    @Test("Pro有効化で既存の停止予約がクリアされる")
    func proActivationClearsPendingStop() {
        // Given: 倍速再生中に残高が尽きてアーム済みになった非Pro状態
        var isPro = false
        let (enforcer, mock, recorder) = Self.makeEnforcer(
            entitlement: .free(remaining: 10),
            isProEntitled: { isPro }
        )
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0)
        mock.entitlementResult = .exhausted
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(10))
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(mock.consumeArgs.first?.seconds == 10)
        let consumeCountBeforePro = mock.consumeArgs.count
        // When: Proを購入して有効化
        isPro = true
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(20))
        // Then: 停止予約が解除され、Pro化後のtickでは消費も再アームもされない
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(mock.consumeArgs.count == consumeCountBeforePro)
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    // MARK: - Exhaustion / Events

    @Test("倍速再生中に残高が尽きた場合は曲境界停止の対象になる")
    func exhaustionDuringPlaybackSetsBoundaryStop() {
        // Given: 残高がある状態で倍速再生を始める
        let (enforcer, mock, recorder) = Self.makeEnforcer(entitlement: .free(remaining: 10))
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0)
        // When: 再生を続けたまま残高が尽きる
        mock.entitlementResult = .exhausted
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(10))
        // Then: 鳴っている曲を切らないため曲末まで許す
        #expect(enforcer.isExhausted)
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("残高が尽きた状態から倍速へ変更した場合は猶予を与えず即座に等速へ戻す")
    func speedUpAfterExhaustionIsRevertedImmediately() {
        let (enforcer, _, recorder) = Self.makeEnforcer(entitlement: .exhausted)
        let t0 = Self.base
        // Given: 等速で再生しており、残高が尽きていることを観測済み
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: t0)
        // When: そこから倍速へ変更する
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(1))
        // Then: 曲末までの猶予は与えない。1曲まるごと無料で聴けてしまうため
        #expect(enforcer.shouldRevertToNormalRateNow())
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received.isEmpty)
    }

    @Test("exhaustedPendingSongEndは二重発行されない")
    func exhaustedEventFiresOnlyOnce() {
        // Given: 倍速再生中に残高が尽きる（猶予が与えられる唯一の経路）
        let (enforcer, mock, recorder) = Self.makeEnforcer(entitlement: .free(remaining: 10))
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0)
        mock.entitlementResult = .exhausted
        // When: 枯渇したまま複数回tick
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(10))
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(20))
        enforcer.tick(isPlaying: false, rate: 1.0, songID: "S1", now: t0.addingTimeInterval(30))
        // Then: イベントは1回だけ
        #expect(recorder.received == [.exhaustedPendingSongEnd])
        #expect(enforcer.shouldStopAtSongBoundary())
    }

    @Test("残高回復するとshouldStopAtSongBoundaryがfalseに戻る")
    func recoveryResetsBoundaryStop() {
        let (enforcer, mock, recorder) = Self.makeEnforcer()
        let t0 = Self.base
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        // When: リワード広告等で残高が回復する
        mock.entitlementResult = .free(remaining: Constants.Allowance.rewardSeconds)
        enforcer.tick(isPlaying: false, rate: 1.0, songID: "S1", now: t0.addingTimeInterval(20))
        // Then: 停止対象が解除され、枯渇イベントは再発行されない
        #expect(!enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("markStoppedAtSongEndで停止予約がクリアされる")
    func markStoppedClearsPendingStop() {
        let (enforcer, mock, recorder) = Self.makeEnforcer()
        Self.exhaustWhileSpedUp(enforcer, mock, at: Self.base)
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
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: Self.base)
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: Self.base.addingTimeInterval(10))
        // Then: 素のApple Music再生は止めないためアームしない
        #expect(enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(recorder.received.isEmpty)
    }

    @Test("枯渇後に等速へ戻しても、同じ曲の猶予は保持される")
    func returningToNormalRateKeepsGraceOnSameSong() {
        let (enforcer, mock, recorder) = Self.makeEnforcer()
        let t0 = Self.base
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        #expect(enforcer.shouldStopAtSongBoundary())
        // When: 倍速のまま枯渇検知後、ユーザーが等速へ戻して再生継続
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: t0.addingTimeInterval(20))
        // Then: 等速へ戻しても猶予は曲に紐付いたまま（解除すると倍速へ戻して猶予を取り直せる）
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(enforcer.isExhausted)
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("枯渇後、倍速と等速を往復しても猶予は1曲ぶんのまま増えない")
    func togglingRateDoesNotRenewGrace() {
        let (enforcer, mock, recorder) = Self.makeEnforcer()
        let t0 = Self.base
        // Given: S1で猶予を取得
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        // When: 等速へ戻してから再び倍速へ上げる（猶予の取り直しを狙う操作）
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", now: t0.addingTimeInterval(20))
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(30))
        // Then: 猶予は増えず、イベントも1度きり
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(!enforcer.shouldRevertToNormalRateNow())
        #expect(recorder.received == [.exhaustedPendingSongEnd])
    }

    @Test("猶予を使い切った後、別の曲で倍速に入ると曲末を待たず等速へ戻す")
    func revertsImmediatelyOnAnotherSong() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // Given: S1で猶予を使い、曲末で停止済み
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        enforcer.markStoppedAtSongEnd()
        // When: 次の曲S2で倍速に入る
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S2", now: t0.addingTimeInterval(20))
        // Then: 曲末までの猶予は与えず、即座に等速へ戻す
        #expect(enforcer.shouldRevertToNormalRateNow())
        #expect(!enforcer.shouldStopAtSongBoundary())
    }

    @Test("猶予中に別の曲へ移っても、停止は曲境界停止が担当し即時復帰は起こさない")
    func songChangeDuringGraceIsHandledByBoundaryStop() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        // When: 停止処理を経ずに次の曲へスキップして倍速のまま再生
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S2", now: t0.addingTimeInterval(20))
        // Then: 曲境界停止が有効なまま。即時復帰と二重に発火させない
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(!enforcer.shouldRevertToNormalRateNow())
    }

    @Test("残高が回復すると猶予の使用履歴もリセットされる")
    func graceIsRenewedAfterBalanceRecovers() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        enforcer.markStoppedAtSongEnd()
        // When: リワードなどで残高が回復し、その後また枯渇する
        mock.entitlementResult = .free(remaining: 600)
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S2", now: t0.addingTimeInterval(20))
        #expect(!enforcer.shouldRevertToNormalRateNow())
        mock.entitlementResult = .exhausted
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S2", now: t0.addingTimeInterval(30))
        // Then: 新しい曲に対して改めて曲末までの猶予が与えられる
        #expect(enforcer.shouldStopAtSongBoundary())
        #expect(!enforcer.shouldRevertToNormalRateNow())
    }

    @Test("停止後に同じ曲を再度倍速へ上げても、猶予は再取得できず等速へ戻される")
    func doesNotRenewGraceWhenNightcoreResumesAfterStop() {
        let (enforcer, mock, recorder) = Self.makeEnforcer()
        let t0 = Self.base
        Self.exhaustWhileSpedUp(enforcer, mock, at: t0)
        enforcer.markStoppedAtSongEnd()
        #expect(!enforcer.shouldStopAtSongBoundary())
        // When: 手動で再度倍速へ上げて再生
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", now: t0.addingTimeInterval(20))
        // Then: 曲末までの猶予は与えず即座に等速へ戻す。枯渇後の猶予は残高が回復するまで1曲ぶん
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(enforcer.shouldRevertToNormalRateNow())
        #expect(recorder.received == [
            .exhaustedPendingSongEnd,
            .stoppedAtSongEnd
        ])
    }

    @Test("isExhaustedは残高状態を表し、停止予約とは独立している")
    func isExhaustedIndependentFromPendingStop() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        Self.exhaustWhileSpedUp(enforcer, mock, at: Self.base)
        // When: 曲境界での停止を完了させる
        enforcer.markStoppedAtSongEnd()
        // Then: 残高は枯渇のまま、停止予約だけが解除される
        #expect(enforcer.isExhausted)
        #expect(!enforcer.shouldStopAtSongBoundary())
    }
}
