import Foundation
import AppTrackingTransparency
@testable import Night_Core_Player

@MainActor
final class TrackingAuthorizationServiceMock: TrackingAuthorizationService {
    var status: ATTrackingManager.AuthorizationStatus = .notDetermined

    private(set) var requestIfNeededCallCount = 0

    /// ATTrackingManager.requestTrackingAuthorization() 後にOSが遷移させる状態を模す
    var statusAfterRequest: ATTrackingManager.AuthorizationStatus = .authorized

    func requestIfNeeded() async {
        guard status == .notDetermined else { return }
        requestIfNeededCallCount += 1
        status = statusAfterRequest
    }
}
