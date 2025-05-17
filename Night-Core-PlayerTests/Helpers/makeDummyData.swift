import Testing
import SwiftUI
import MusicKit

public func makeDummySong(id: String) -> Song {
    let data = """
    { "id":"\(id)",
      "type":"songs",
      "attributes": { "name":"DummyTitle", "artistName":"DummyArtist" }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Song.self, from: data)
}

public func makeDummyPlaylist(id: String, name: String = "DummyList") -> Playlist {
    let data = """
    { "id":"\(id)",
      "type":"playlists",
      "attributes": { "name":"\(name)" }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(Playlist.self, from: data)
}
