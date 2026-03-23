# MusicKit Artist API 調査

> 調査日: 2026-03-23

---

## アーティスト検索

```swift
var request = MusicCatalogSearchRequest(term: "Adele", types: [Artist.self])
request.limit = 5  // デフォルト5、最大25。型ごとに適用
let response = try await request.response()
let artists = response.artists  // MusicItemCollection<Artist>
```

Song と Artist を同時に検索可能:

```swift
var request = MusicCatalogSearchRequest(
    term: "The Weeknd",
    types: [Song.self, Artist.self]
)
request.limit = 25  // Song に25、Artist に25（独立）
let response = try await request.response()
let songs = response.songs
let artists = response.artists
```

## Artist 型の主要プロパティ

| プロパティ | 型 | 説明 |
|---|---|---|
| `id` | `MusicItemID` | 一意識別子 |
| `name` | `String` | アーティスト名 |
| `artwork` | `Artwork?` | アートワーク（nil の場合あり） |
| `url` | `URL?` | Apple Music URL |
| `topSongs` | `MusicItemCollection<Song>?` | 要 `.with([.topSongs])` |
| `albums` | `MusicItemCollection<Album>?` | 要 `.with([.albums])` |

## topSongs の取得

```swift
let detailedArtist = try await artist.with([.topSongs])
let songs = Array(detailedArtist.topSongs ?? [])
```

- 返却件数は Apple 側が決定（通常 20 曲前後）
- MusicKit Swift 側で件数を明示指定する API はない
- REST API の上限は 25

## 制約

| 対象 | デフォルト | 最大 |
|---|---|---|
| `MusicCatalogSearchRequest.limit`（型ごと） | 5 | 25 |
| `topSongs` | Apple側決定 | 約20-25曲 |

## Sources

- [MusicCatalogSearchRequest | Apple Developer](https://developer.apple.com/documentation/musickit/musiccatalogsearchrequest)
- [Artist | Apple Developer](https://developer.apple.com/documentation/musickit/artist)
- [WWDC22: Explore more content with MusicKit](https://developer.apple.com/videos/play/wwdc2022/110347/)
