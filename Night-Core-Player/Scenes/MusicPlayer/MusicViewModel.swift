import SwiftUI

@MainActor
class MusicPlayerViewModel: ObservableObject {
    // —————————————————————
    // MARK: – Published Properties
    // —————————————————————
    @Published var trackTitle: String = "Believer"
    @Published var artistName: String = "IMAGINE DRAGONS"
    @Published var artworkImage: Image = Image("album_art_placeholder")
    @Published var currentTime: Double = 50    // 現在の再生時間
    @Published var musicDuration: Double = 240      // 音楽再生時間
    @Published var rate: Double = 1.15
    @Published var isPlaying: Bool = true
    

    // —————————————————————
    // MARK: – Actions (ダミー)
    // —————————————————————
    func previousTrack() { /* TODO */ }
    func nextTrack()     { /* TODO */ }
    func togglePlayPause() {
        isPlaying.toggle()
    }
    func changeRate(by delta: Double) {
        let new = rate + delta
        rate = min(max(new, 0.5), 3.0)
    }
    func rewind15() { /* TODO */ }
    func forward15() { /* TODO */ }
}

