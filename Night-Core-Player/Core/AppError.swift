import Foundation

enum AppError: LocalizedError {
    case musicKit(underlying: Error)
    case player(String)
    case persistence(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .musicKit(let error):
            return "MusicKit エラー: \(error.localizedDescription)"
        case .player(let message):
            return "再生エラー: \(message)"
        case .persistence(let error):
            return "データ保存エラー: \(error.localizedDescription)"
        }
    }
}
