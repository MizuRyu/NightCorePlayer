import Testing
import Foundation
import Combine
import NightCoreDomain
import NightCoreDomainTestSupport

/// 再生位置を渡さないtick。位置が取れない場合の wall-clock フォールバックが対象のケース用
@MainActor
private extension AllowanceEnforcerImpl {
    func tick(isPlaying: Bool, rate: Double, songID: String?, now: Date) {
        tick(isPlaying: isPlaying, rate: rate, songID: songID, playbackPosition: nil, now: now)
    }
}

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

    @Test("tick: tickが欠落しても、実際に進んだ再生位置ぶんは消費される")
    func tickConsumesActualPlaybackAcrossLongGap() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: tickが1時間欠落し、その間ずっと2倍速で鳴っていた（位置は7200秒進む）
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 7200,
            now: t0.addingTimeInterval(3600)
        )
        // Then: 実再生1時間ぶんが消費される（旧仕様の60秒クランプによる過少消費は起きない）
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 3600)
    }

    @Test("tick: gapが長くても再生位置が進んでいなければ位置ぶんしか消費しない")
    func tickDoesNotConsumeWallClockWhenPositionBarelyAdvanced() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // When: 1時間の gap だが、実際には10秒しか鳴っていなかった
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 100, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 110,
            now: t0.addingTimeInterval(3600)
        )
        // Then: 10秒ぶんの倍速再生に費やした実時間 = 10 / 2.0
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 5)
    }

    @Test("tick: 後方シークしたtickは経過実時間ぶんだけ消費する")
    func tickWithBackwardSeekConsumesWallDeltaOnly() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 200, now: t0)
        // When: 曲の先頭へ戻す（通常のtick間隔である0.5秒後）
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 0,
            now: t0.addingTimeInterval(0.5)
        )
        // Then: 位置で裏が取れないためフォールバック。上限60秒には遠く、実質誤差のない0.5秒
        #expect(mock.consumeArgs.map(\.seconds) == [0.5])
    }

    @Test("tick: 位置が進まないまま長時間経過した場合はフォールバック上限の60秒まで消費する")
    func tickWithoutPositionProgressIsCappedAtFallbackMax() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // Given: repeat-one で周回し、30分後のtickで位置が偶然同じだった（位置差から実再生量が読めない）
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 120, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 120,
            now: t0.addingTimeInterval(1800)
        )
        // Then: 位置で裏が取れない区間は保守的に60秒までしか請求しない
        #expect(mock.consumeArgs.map(\.seconds) == [60])
    }

    @Test("tick: 前方シークしても経過実時間を超えて消費しない")
    func tickWithForwardSeekIsCappedByWallDelta() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        // When: 10秒後のtickまでの間に大きく先へシークする
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 10_000,
            now: t0.addingTimeInterval(10)
        )
        // Then: 消費は経過実時間の10秒が上限
        #expect(mock.consumeArgs.count == 1)
        #expect(mock.consumeArgs.first?.seconds == 10)
    }

    @Test("tick: 再生位置が取れない場合は経過実時間を消費する")
    func tickWithoutPositionFallsBackToWallClock() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: nil, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: nil,
            now: t0.addingTimeInterval(30)
        )
        // Then: 上限60秒に収まる区間なので経過実時間ぶんを消費
        #expect(mock.consumeArgs.map(\.seconds) == [30])
    }

    @Test("tick: 再生位置が取れないまま長時間経過した場合は60秒までしか消費しない")
    func tickWithoutPositionIsCappedAtFallbackMax() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: nil, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: nil,
            now: t0.addingTimeInterval(3600)
        )
        #expect(mock.consumeArgs.map(\.seconds) == [60])
    }

    @Test("tick: 曲が変わったtickは経過実時間を消費し、基準は新しい曲で再設定される")
    func tickOnSongChangeFallsBackThenRebaselines() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        // When: 次の曲へ移る（S1の位置とは比較できない）
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S2",
            playbackPosition: 5,
            now: t0.addingTimeInterval(10)
        )
        // そのまま S2 の再生を続ける
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S2",
            playbackPosition: 45,
            now: t0.addingTimeInterval(30)
        )
        // Then: 曲が変わったtickは実時間10秒、続くtickは S2 の位置差(40) / 2.0 = 20秒
        #expect(mock.consumeArgs.map(\.seconds) == [10, 20])
    }

    @Test("tick: 等速では再生位置が進んでいても消費しない")
    func tickNormalRateDoesNotConsumeEvenWithPosition() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", playbackPosition: 0, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 1.0,
            songID: "S1",
            playbackPosition: 30,
            now: t0.addingTimeInterval(30)
        )
        #expect(mock.consumeArgs.isEmpty)
    }

    @Test("tick: スロー再生も消費対象で、費やした実時間ぶんが請求される")
    func tickSlowRateConsumesWallClock() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // Given: 0.5倍速（rate != 1.0 なので消費対象）で10秒再生し、位置は5秒しか進まない
        enforcer.tick(isPlaying: true, rate: 0.5, songID: "S1", playbackPosition: 0, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 0.5,
            songID: "S1",
            playbackPosition: 5,
            now: t0.addingTimeInterval(10)
        )
        // Then: 5 / 0.5 = 10秒。位置ではなく費やした実時間で課金される
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("tick: 倍速から一時停止へ遷移したtickでも、直前の倍速区間は消費される")
    func tickConsumesPreviousSpedUpIntervalOnPauseTransition() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(10)
        )
        // When: 次のtickまでの10秒のうち、5秒ぶん（位置+10）鳴ってから一時停止した
        enforcer.tick(
            isPlaying: false,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 30,
            now: t0.addingTimeInterval(20)
        )
        // Then: 遷移tickでも直前区間を取りこぼさず、かつ鳴っていた5秒ぶんだけを消費する
        #expect(mock.consumeArgs.map(\.seconds) == [10, 5])
    }

    @Test("tick: 倍速から等速へ遷移したtickでは、直前の倍速レートで消費される")
    func tickConsumesWithPreviousRateOnRateChange() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        // When: 10秒間2倍速で鳴った後、このtickで等速へ戻した
        enforcer.tick(
            isPlaying: true,
            rate: 1.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(10)
        )
        // Then: 区間を支配していた倍速(2.0)で計算し、20 / 2.0 = 10秒を消費
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("tick: 等速から倍速へ切り替えたtickは消費しない")
    func tickDoesNotConsumeOnSpeedUpTransition() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", playbackPosition: 0, now: t0)
        // When: このtickで倍速へ上げる（直前の10秒間は等速だった）
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 10,
            now: t0.addingTimeInterval(10)
        )
        // さらに10秒倍速で再生
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 30,
            now: t0.addingTimeInterval(20)
        )
        // Then: 切替tickは等速区間なので消費0。以降のtickから消費が始まる
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("tick: 長時間の一時停止から曲変更+倍速再生へ移ったtickは消費しない")
    func tickAfterLongPauseDoesNotConsumeOnSongChange() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        // Given: 一時停止のまま1時間放置される
        enforcer.tick(isPlaying: false, rate: 2.0, songID: "S1", playbackPosition: 100, now: t0)
        enforcer.tick(
            isPlaying: false,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 100,
            now: t0.addingTimeInterval(1800)
        )
        // When: 別の曲を倍速で再生し始める（位置での検算はできない曲変更tick）
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S2",
            playbackPosition: 0,
            now: t0.addingTimeInterval(3600)
        )
        // その10秒後から通常の計測に入る
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S2",
            playbackPosition: 20,
            now: t0.addingTimeInterval(3610)
        )
        // Then: 放置区間は非再生なので消費0。曲変更tickもフォールバックへ落ちずに消費0
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("tick: 時計が逆行しても消費0で、以後の計測も破綻しない")
    func tickWithClockReversalConsumesNothing() {
        let (enforcer, mock, _) = Self.makeEnforcer()
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        // When: 端末の時計が10秒戻された状態でtickが来る
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(-10)
        )
        #expect(mock.consumeArgs.isEmpty)
        // Then: 逆行後の基準からも通常どおり計測される（10秒経過・位置+20 → 10秒）
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 40,
            now: t0
        )
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("Pro期間ぶんは解除後のtickでも消費されない")
    func proPeriodIsNotConsumedAfterProEnds() {
        var isPro = false
        let (enforcer, mock, _) = Self.makeEnforcer(isProEntitled: { isPro })
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        // Given: Pro有効のまま1時間倍速で再生する
        isPro = true
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(10)
        )
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 7200,
            now: t0.addingTimeInterval(3600)
        )
        // When: Proが切れて次のtickが来る
        isPro = false
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 7220,
            now: t0.addingTimeInterval(3610)
        )
        // Then: Pro中も時刻・状態・位置の基準を進めているため、消費はPro解除後の10秒ぶんだけ
        #expect(mock.consumeArgs.map(\.seconds) == [10])
    }

    @Test("Pro解除直後は残高の観測をやり直すため、枯渇したままなら猶予を与えず等速へ戻す")
    func proExpiryDoesNotGrantGraceWhenExhausted() {
        var isPro = false
        let (enforcer, _, recorder) = Self.makeEnforcer(
            entitlement: .exhausted,
            isProEntitled: { isPro }
        )
        let t0 = Self.base
        // Given: 非Proの等速再生で枯渇を観測している
        enforcer.tick(isPlaying: true, rate: 1.0, songID: "S1", playbackPosition: 0, now: t0)
        // Proを有効化して倍速で再生する
        isPro = true
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(10)
        )
        // When: 実残高0のままProが失効し、倍速のまま再生が続く
        isPro = false
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 40,
            now: t0.addingTimeInterval(20)
        )
        // Then: 「残高があるうちから鳴っていた」とは扱わず、猶予なしで等速へ戻す
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(enforcer.shouldRevertToNormalRateNow())
        #expect(recorder.received.isEmpty)
    }

    @Test("Pro解除時に残高が残っていれば、観測やり直し後も倍速再生は妨げられない")
    func proExpiryWithRemainingBalanceKeepsPlaying() {
        var isPro = false
        let (enforcer, mock, recorder) = Self.makeEnforcer(
            entitlement: .free(remaining: 600),
            isProEntitled: { isPro }
        )
        let t0 = Self.base
        enforcer.tick(isPlaying: true, rate: 2.0, songID: "S1", playbackPosition: 0, now: t0)
        isPro = true
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 20,
            now: t0.addingTimeInterval(10)
        )
        // When: 残高が残っている状態でProが失効する
        isPro = false
        enforcer.tick(
            isPlaying: true,
            rate: 2.0,
            songID: "S1",
            playbackPosition: 40,
            now: t0.addingTimeInterval(20)
        )
        // Then: 停止も等速復帰も起こらず、Pro解除後の区間だけが消費される
        #expect(!enforcer.shouldStopAtSongBoundary())
        #expect(!enforcer.shouldRevertToNormalRateNow())
        #expect(recorder.received.isEmpty)
        #expect(mock.consumeArgs.map(\.seconds) == [10])
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
