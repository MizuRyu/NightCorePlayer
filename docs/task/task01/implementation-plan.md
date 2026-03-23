# task01: 実装計画

> 作成日: 2026-03-23
> 前提: spec.md の仕様に基づく

---

## 実装順序

依存関係を考慮し、以下の順で実装する。

### Step 1: サウンドアイコン修正（独立、最小）

対象: `MusicPlayerView.swift`

- 曲未セット時のアートワーク表示を分岐
- `artworkData == nil` なら小さい music.note アイコン + 背景
- ビルド確認

### Step 2: MusicKitService にアーティスト API 追加

対象: `Services/MusicKitService.swift`

- `MusicKitClient` protocol に `searchCatalogArtists`, `fetchArtistTopSongs` 追加
- `DefaultMusicKitClient` に実装
- `MusicKitService` protocol に `searchArtists`, `fetchArtistTopSongs` 追加
- `MusicKitServiceImpl` に実装
- Mock 更新: `MusicKitServiceMock` に追加
- テスト追加: `MusicKitServiceTests` にアーティスト検索テスト
- ビルド + テスト確認

### Step 3: SearchViewModel にアーティスト検索追加

対象: `Features/Search/SearchViewModel.swift`

- `artists: [Artist]` プロパティ追加
- `performSearch` で `async let` により曲 + アーティストを並行取得
- テスト追加: `SearchViewModelTests` にアーティスト結果のテスト
- ビルド + テスト確認

### Step 4: ArtistRowView + 検索結果 UI 更新

対象: `Features/Search/ArtistRowView.swift`（新規）、`Features/Search/SearchView.swift`

- `ArtistRowView` 作成（丸型アートワーク + アーティスト名 + シェブロン）
- `SearchView` のリストにアーティスト行を追加（アーティスト先、曲後）
- `NavigationDestination` 追加（Artist → ArtistDetailView）
- ビルド確認

### Step 5: ArtistDetailView + ViewModel

対象: `Features/Search/ArtistDetailView.swift`（新規）、`Features/Search/ArtistDetailViewModel.swift`（新規）

- `ArtistDetailViewModel` 作成（PlaylistDetailViewModel と同構造）
- `ArtistDetailView` 作成（PlaylistDetailView と同構造）
  - 再生 / シャッフルボタン
  - 楽曲リスト（SongRowView 再利用）
  - 1曲タップ → その曲から順再生
- テスト追加: `ArtistDetailViewModelTests`
- ビルド + テスト確認

### Step 6: 検索タブダブルタップ

対象: `Features/Common/PlayerNavigator.swift`、`Features/Common/MainTabView.swift`、`Features/Search/SearchView.swift`

- `PlayerNavigator` に `searchBarFocusRequested` フラグ追加
- `MainTabView` でダブルタップ検知ロジック追加
- `SearchView` に `@FocusState` 追加、フォーカスリクエスト処理
- SwiftUI TabView の制約を実装時に検証
- ビルド確認

---

## テスト計画

| Step | 追加テスト |
|------|-----------|
| 2 | `MusicKitServiceTests`: アーティスト検索、topSongs 取得、認証チェック |
| 3 | `SearchViewModelTests`: アーティスト結果の取得、空結果 |
| 5 | `ArtistDetailViewModelTests`: load 成功/失敗、重複ロード防止 |
