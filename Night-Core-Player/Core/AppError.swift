import Foundation

enum AppError: LocalizedError {
    case musicKit(underlying: Error)
    case player(String)
    case persistence(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .musicKit(let error):
            return String(localized: "MusicKit Error: \(error.localizedDescription)")
        case .player(let message):
            return String(localized: "Playback Error: \(message)")
        case .persistence(let error):
            return String(localized: "Data Save Error: \(error.localizedDescription)")
        }
    }
}
