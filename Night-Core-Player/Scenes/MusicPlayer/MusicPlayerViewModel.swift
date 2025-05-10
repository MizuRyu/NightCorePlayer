import SwiftUI

@MainActor
class MusicPlayerViewModel: ObservableObject {
    struct Track {
        let title: String
        let artist: String
        let artworkName: String
    }
    
    private let tracks: [Track] = [
        .init(title: "Belever", artist: "IMAGINE DRAGONS", artworkName: "imgAssets1"),
        .init(title: "Killer", artist: "IMAGINE DRAGONS", artworkName: "imgAssets2")
    ]
    
    @Published private(set) var currentTrackIndex: Int = 0
    @Published private(set) var trackTitle: String = ""
    @Published private(set) var artistName: String = ""
    @Published private(set) var artworkImage: Image = Image("")

    @Published var currentTime: Double = 50
    @Published var musicDuration: Double = 240 
    @Published var rate: Double = 1.15
    @Published var isPlaying: Bool = true
    
    init() {
        updateTrack()
    }
    

    func previousTrack() {
        currentTrackIndex = ( currentTrackIndex - 1 + tracks.count) % tracks.count
        updateTrack()
        
    }
    func nextTrack() {
        currentTrackIndex = ( currentTrackIndex + 1 + tracks.count) % tracks.count
        updateTrack()
    }
    func togglePlayPause() {
        isPlaying.toggle()
    }
    func changeRate(by delta: Double) {
        let new = rate + delta
        rate = min(max(new, 0.5), 3.0)
    }
    func rewind15() { /* TODO */ }
    func forward15() { /* TODO */ }
    
    private func updateTrack() {
        let t = tracks[currentTrackIndex]
        trackTitle = t.title
        artistName = t.artist
        artworkImage = Image(t.artworkName)
    }
}
