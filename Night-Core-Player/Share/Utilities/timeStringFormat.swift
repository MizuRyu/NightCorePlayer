import Foundation

// —————————————————————
// MARK: – Helpers
// —————————————————————
public func timeString(from seconds: Double) -> String {
    let s = Int(seconds)
    return String(format: "%02d:%02d", s/60, s%60)
}
