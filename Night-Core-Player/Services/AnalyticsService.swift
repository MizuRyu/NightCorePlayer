import Foundation
import NightCoreDomain
import os
import TelemetryDeck

// MARK: - Protocol

/// 呼び出し側に文字列を書かせず、型付きイベントで計測する(#68)
@MainActor
protocol AnalyticsService: Sendable {
    /// DAU相当
    func appLaunched()
    /// リワード付与。#62のフォールバック(広告が出せない時も付与)をviaAdで区別する
    func rewardGranted(viaAd: Bool)
    func proPurchased()
    /// 残高が尽きた
    func balanceDepleted()
}

// MARK: - Impl

@MainActor
final class AnalyticsServiceImpl: AnalyticsService {
    private let logger = Logger(subsystem: Constants.Logging.subsystem, category: "Analytics")
    private let isEnabled: Bool

    /// App ID未発行のプレースホルダのままなら初期化・送信ともno-opにする。
    /// -DEMO時はデモ録画・スクリーンショット撮影を計測で汚さないよう常にno-opにする
    init(
        appID: String = Constants.Analytics.appID,
        isDemo: Bool = false
    ) {
        guard !isDemo, appID != Constants.Analytics.placeholderAppID, !appID.isEmpty else {
            isEnabled = false
            return
        }
        isEnabled = true
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    func appLaunched() {
        send("App.launched")
    }

    func rewardGranted(viaAd: Bool) {
        send("Allowance.rewardGranted", parameters: ["viaAd": String(viaAd)])
    }

    func proPurchased() {
        send("Pro.purchased")
    }

    func balanceDepleted() {
        send("Allowance.balanceDepleted")
    }

    // MARK: - Private

    private func send(_ signalName: String, parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        // parametersの値はSDK側でハッシュ化されないため、個人情報を含めないこと
        TelemetryDeck.signal(signalName, parameters: parameters)
        logger.info("Signal sent: \(signalName)")
    }
}
