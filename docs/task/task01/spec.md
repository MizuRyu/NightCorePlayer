# task01: 検索画面の改善 + アーティスト機能

> 作成日: 2026-03-23
> ステータス: ドラフト（ユーザーレビュー待ち）

---

## 要件サマリ

1. **サウンドアイコンのサイズ修正** — 曲未セット時の music.note アイコンが大きすぎる
2. **アーティスト検索** — 検索結果に曲だけでなくアーティストも表示
3. **アーティスト詳細画面** — アーティストをタップすると楽曲一覧が開く（プレイリスト詳細に似たUI）
4. **アーティスト楽曲の再生** — 全再生、シャッフル、1曲タップで以降順再生
5. **検索タブのダブルタップ** — 検索バーにフォーカスして入力状態にする

---

## 1. サウンドアイコンのサイズ修正

### 現状
`MusicPlayerView.swift:74` で `vm.artworkImage` を 250x250 で表示。曲未セット時は `Image(systemName: "music.note")` がそのまま 250x250 に引き伸ばされる。

### 修正方針
曲未セット時（`artworkData == nil`）のアイコンサイズを小さくする。

```swift
// MusicPlayerViewModel.swift の artworkImage computed property を修正
var artworkImage: Image {
    if let data = artworkData, let ui = UIImage(data: data) {
        return Image(uiImage: ui)
    }
    return Image(systemName: "music.note")
}

// MusicPlayerView.swift 側で分岐
if vm.artworkData != nil {
    vm.artworkImage
        .resizable()
        .scaledToFit()
        .frame(width: 250, height: 250)
        .cornerRadius(12)
} else {
    Image(systemName: "music.note")
        .font(.system(size: 80))       // アイコンサイズを適度に
        .foregroundColor(.secondary)
        .frame(width: 250, height: 250)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
}
```

---

## 2. アーティスト検索

### 現状
`SearchViewModel` は `MusicKitService.searchSongs()` で曲のみ検索している。

### 変更内容

#### MusicKitService に追加するメソッド

```swift
// Protocol に追加
func searchArtists(keyword: String, limit: Int) async throws -> [Artist]
func fetchArtistTopSongs(artist: Artist) async throws -> [Song]
```

#### MusicKitClient に追加

```swift
func searchCatalogArtists(term: String, limit: Int) async throws -> [Artist]
func fetchArtistTopSongs(artist: Artist) async throws -> [Song]
```

#### SearchViewModel の変更

```swift
@Observable
@MainActor
final class SearchViewModel {
    private(set) var songs: [Song] = []
    private(set) var artists: [Artist] = []  // 追加
    // ...

    func performSearch(keyword: String) async {
        // songs と artists を並行取得
        async let fetchedSongs = musicKitService.searchSongs(keyword: trimmed, limit: 25)
        async let fetchedArtists = musicKitService.searchArtists(keyword: trimmed, limit: 5)

        songs = try await fetchedSongs
        artists = try await fetchedArtists
    }
}
```

### 検索結果の表示（混在リスト）

曲とアーティストを同じリストに並べる。アーティストを先頭に、曲をその後に表示。
カードのデザインで区別する。

```
┌────────────────────────────────────────┐
│ 🔍 [検索バー]                            │
├────────────────────────────────────────┤
│ 🎤 Artist Card                          │
│ ┌──────┐                                │
│ │ 丸型  │ アーティスト名                   │
│ │artwork│                    >           │
│ └──────┘                                │
├────────────────────────────────────────┤
│ 🎵 Song Card（既存の SearchRowView）      │
│ ┌──────┐                                │
│ │ 四角型│ 曲名                            │
│ │artwork│ アーティスト名      ⋮           │
│ └──────┘                                │
├────────────────────────────────────────┤
│ 🎵 Song Card                            │
│ ...                                     │
└────────────────────────────────────────┘
```

#### ArtistRowView（新規）

```swift
struct ArtistRowView: View {
    let artist: Artist

    var body: some View {
        HStack {
            // 丸型アートワーク（アーティストは丸で区別）
            if let url = artist.artwork?.url(width: 48, height: 48) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }

            Text(artist.name)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

**曲カード vs アーティストカード の区別:**
- **曲**: 四角いアートワーク + 曲名 + アーティスト名 + コンテキストメニュー（⋮）
- **アーティスト**: 丸いアートワーク + アーティスト名 + シェブロン（>）

---

## 3. アーティスト詳細画面

### UI（PlaylistDetailView に類似）

```
┌────────────────────────────────────────┐
│ ← アーティスト名                         │
├────────────────────────────────────────┤
│  [▶ 再生]         [🔀 シャッフル]        │
├────────────────────────────────────────┤
│ 🎵 曲1                                  │
│ 🎵 曲2                                  │
│ 🎵 曲3                                  │
│ ...                                     │
└────────────────────────────────────────┘
```

### ArtistDetailView（新規）

PlaylistDetailView と同じ構造：
- 上部: 再生ボタン + シャッフルボタン
- 下部: 楽曲リスト（`SongRowView` を再利用）
- Loading / Error / Loaded の3状態

### ArtistDetailViewModel（新規）

```swift
@Observable
@MainActor
final class ArtistDetailViewModel {
    let artist: Artist
    private(set) var songs: [Song] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let musicKitService: MusicKitService

    init(artist: Artist, musicKitService: MusicKitService) {
        self.artist = artist
        self.musicKitService = musicKitService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            songs = try await musicKitService.fetchArtistTopSongs(artist: artist)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            songs = []
        }
    }
}
```

### 楽曲タップの挙動

**タップした曲から順に再生する。** アーティストの全楽曲をキューに入れ、タップした曲のインデックスから再生開始。

```swift
Button {
    let idx = vm.songs.firstIndex { $0.id == song.id } ?? 0
    playerVM.loadPlaylist(songs: vm.songs, startAt: idx, autoPlay: true)
    nav.selectedTab = .player
} label: {
    SongRowView(song: song)
}
```

---

## 4. アーティスト楽曲の取得（MusicKit API）

### topSongs の仕様

- `artist.with([.topSongs])` で取得
- Apple Music 側が返す楽曲数に依存（通常 20 曲前後。明示的な limit 指定は不可）
- 25 曲を上限として扱う（ユーザー回答）

### 実装

```swift
// MusicKitService (MusicKitClient) に追加
func fetchArtistTopSongs(artist: Artist) async throws -> [Song] {
    let detailed = try await artist.with([.topSongs])
    return Array(detailed.topSongs?.prefix(25) ?? [])
}
```

---

## 5. 検索タブのダブルタップ

### 挙動
検索タブを2回連続タップすると、検索バーの TextField にフォーカスが移る。

### 実装方針

`PlayerNavigator` でタブ選択のタイミングを検知し、既に search タブにいる状態でもう一度タップされたらフォーカスフラグを立てる。

```swift
// PlayerNavigator に追加
var searchBarFocusRequested: Bool = false

// MainTabView の TabView onChange で検知
.onChange(of: nav.selectedTab) { oldTab, newTab in
    if oldTab == .search && newTab == .search {
        nav.searchBarFocusRequested = true
    }
}
```

ただし SwiftUI の `TabView` は同じタブの再選択を `onChange` で検知できない場合がある。代替案：

```swift
// SearchView に @FocusState を追加
@FocusState private var isSearchBarFocused: Bool

TextField("曲名・アーティスト名", text: $vm.query)
    .focused($isSearchBarFocused)

// onAppear でフォーカスリクエストをチェック
.onAppear {
    if nav.searchBarFocusRequested {
        isSearchBarFocused = true
        nav.searchBarFocusRequested = false
    }
}
```

> **注意**: SwiftUI の TabView で「同じタブの再タップ」を正確に検知するのは制約がある。実装時に挙動を確認し、必要ならカスタム TabView or UIKit ブリッジで対応する可能性あり。

---

## 変更ファイル一覧

### 新規作成

| ファイル | 配置先 | 内容 |
|----------|--------|------|
| `ArtistRowView.swift` | `Features/Search/` | アーティスト用の検索結果行 |
| `ArtistDetailView.swift` | `Features/Search/` | アーティスト詳細画面（楽曲一覧） |
| `ArtistDetailViewModel.swift` | `Features/Search/` | アーティスト詳細のVM |

### 変更

| ファイル | 変更内容 |
|----------|---------|
| `Services/MusicKitService.swift` | `searchArtists`, `fetchArtistTopSongs` 追加（Protocol + Impl + Client） |
| `Features/Search/SearchViewModel.swift` | `artists: [Artist]` プロパティ追加、検索で曲+アーティスト並行取得 |
| `Features/Search/SearchView.swift` | リスト表示にアーティスト行を追加、NavigationDestination 追加 |
| `Features/MusicPlayer/MusicPlayerView.swift` | 曲未セット時のアイコンサイズ修正 |
| `Features/Common/PlayerNavigator.swift` | `searchBarFocusRequested` フラグ追加 |
| `Features/Common/MainTabView.swift` | ダブルタップ検知ロジック追加（実装可能性の確認が必要） |

### テスト

| ファイル | 内容 |
|----------|------|
| `Mock/MusicKitServiceMock.swift` | `searchArtists`, `fetchArtistTopSongs` のMock追加 |
| `Features/Search/SearchViewModelTests.swift` | アーティスト検索のテスト追加 |
| `Services/MusicKitServiceTests.swift` | アーティスト関連メソッドのテスト追加 |

---

## 未確定事項

- [ ] SwiftUI TabView での同タブ再タップ検知の実現可能性（実装時に検証が必要）
- [ ] アーティスト詳細画面のアートワークヘッダ表示有無（Apple Music のようにアーティスト画像を大きく表示するか、シンプルにリストだけにするか）
