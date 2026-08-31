import Foundation
import NightCoreDomain

enum AppError: LocalizedError {
    case musicKit(underlying: Error)
    case player(String)
    case persistence(underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .musicKit(error):
            return String(localized: "MusicKit Error: \(error.localizedDescription)")
        case let .player(message):
            return String(localized: "Playback Error: \(message)")
        case let .persistence(error):
            return String(localized: "Data Save Error: \(error.localizedDescription)")
        }
    }
}

extension AppError {
    /// Domain のエラーをユーザー向け文言へ写す。ローカライズ資源はアプリ側にしか無いため、
    /// 文言の生成は Domain ではなくここが担う
    init(_ error: AllowanceError) {
        switch error {
        case .dailyRewardLimitReached:
            self = .player(String(localized: "You've reached today's ad limit. It resets tomorrow."))
        }
    }
}
