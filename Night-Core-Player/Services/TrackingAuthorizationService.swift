//
//  TrackingAuthorizationService.swift
//  Night-Core-Player
//

import Foundation
import AppTrackingTransparency
import os
import NightCoreDomain

// MARK: - Protocol

@MainActor
protocol TrackingAuthorizationService: Sendable {
    var status: ATTrackingManager.AuthorizationStatus { get }
    /// .notDetermined の場合のみシステムダイアログを表示し、完了まで待つ
    func requestIfNeeded() async
}

// MARK: - Impl

@MainActor
final class TrackingAuthorizationServiceImpl: TrackingAuthorizationService {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Tracking")

    var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    func requestIfNeeded() async {
        guard status == .notDetermined else { return }
        let result = await ATTrackingManager.requestTrackingAuthorization()
        logger.info("ATT authorization requested, result: \(String(describing: result))")
    }
}
