import SwiftUI
import Observation

/// Settings 画面のデフォルト再生速度を管理する ViewModel
@Observable
@MainActor
final class SettingsViewModel {
    var defaultRate: Double
    var errorMessage: String?

    private let rateManager: PlaybackRateManager
    private let playerService: MusicPlayerService

    init(rateManager: PlaybackRateManager, playerService: MusicPlayerService) {
        self.rateManager = rateManager
        self.playerService = playerService
        self.defaultRate = rateManager.defaultRate
    }

    /// デフォルト再生速度を更新し、現在のセッションにも即反映する
    func updateDefaultRate(to rate: Double) {
        let clamped = min(
            max(rate, Constants.MusicPlayer.minPlaybackRate),
            Constants.MusicPlayer.maxPlaybackRate
        )
        defaultRate = clamped
        Task {
            do {
                try rateManager.setDefaultRate(clamped)
            } catch {
                errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            await playerService.setSessionRate(clamped)
        }
    }
}
