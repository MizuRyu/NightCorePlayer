import SwiftUI
import Observation

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
