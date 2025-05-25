import Testing
import SwiftUI
import MusicKit
import MediaPlayer

public func makeDummySong(
    id: String,
    title: String = "-",
    duration: TimeInterval = 0
) -> Song {
    let millis = Int(duration * 1000)
    let data = """
    {
      "id":"\(id)",
      "type":"songs",
      "attributes": {
        "title":"\(title)",
        "artistName":"DummyArtist",
        "durationInMillis":\(millis),
        "playParams": {
          "kind": "song",
          "catalogId": "\(id)",
          "id": "\(id)"
        }
      }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Song.self, from: data)
}


public func makeDummyPlaylist(
    id: String,
    name: String = "DummyList",
) -> Playlist {
    let data = """
    { "id":"\(id)",
      "type":"playlists",
      "attributes": { "name":"\(name)" }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Playlist.self, from: data)
}