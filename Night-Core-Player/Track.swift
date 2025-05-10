import Foundation

public struct Track: Identifiable {
    public let id = UUID()
    public let title: String
    public let artist: String
    public let artworkName: String
    public let fileURL: URL
    
    public init(
        title: String,
        artist: String,
        artworkName: String,
        fileURL: URL
    )
    {
        self.title = title
        self.artist = artist
        self.artworkName = artworkName
        self.fileURL = fileURL
    }
}
