import AppTrackingTransparency
import Testing
@testable import Night_Core_Player

@Suite("TrackingAuthorizationService Tests")
@MainActor
struct TrackingAuthorizationServiceTests {
    @Test("requestIfNeeded: notDetermined時は要求してauthorizedへ遷移すること")
    func requestIfNeeded_notDetermined_requests() async {
        let mock = TrackingAuthorizationServiceMock()
        mock.status = .notDetermined

        await mock.requestIfNeeded()

        #expect(mock.requestIfNeededCallCount == 1, "notDetermined時は要求が1回行われること")
        #expect(mock.status == .authorized, "要求後はOSが返した状態に遷移すること")
    }

    @Test("requestIfNeeded: authorized済みの場合は再要求しないこと")
    func requestIfNeeded_authorized_doesNotRequest() async {
        let mock = TrackingAuthorizationServiceMock()
        mock.status = .authorized

        await mock.requestIfNeeded()

        #expect(mock.requestIfNeededCallCount == 0, "既に確定済みの状態では要求しないこと")
    }

    @Test("requestIfNeeded: denied済みの場合は再要求しないこと")
    func requestIfNeeded_denied_doesNotRequest() async {
        let mock = TrackingAuthorizationServiceMock()
        mock.status = .denied

        await mock.requestIfNeeded()

        #expect(mock.requestIfNeededCallCount == 0, "拒否済みの状態では要求しないこと")
    }

    @Test("requestIfNeeded: restricted済みの場合は再要求しないこと")
    func requestIfNeeded_restricted_doesNotRequest() async {
        let mock = TrackingAuthorizationServiceMock()
        mock.status = .restricted

        await mock.requestIfNeeded()

        #expect(mock.requestIfNeededCallCount == 0, "制限済みの状態では要求しないこと")
    }
}
