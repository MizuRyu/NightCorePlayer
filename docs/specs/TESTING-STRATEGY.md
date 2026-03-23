# NightCorePlayer テスト方針

> 最終更新: 2026-03-23

---

## テスト基本方針

- **Given-When-Then** で書く。例外なし
- **Swift Testing** (`@Test`, `#expect`, `#require`) を使用
- **新規コードはテストファースト**
- **View テストは書かない**（ロジックは ViewModel に集約済み）

---

## カバレッジ目標

### 全体目標: 60% 以上

| レイヤー | 目標 | 理由 |
|---------|------|------|
| Services | **80%** | ビジネスロジックの中心。バグのコストが最も高い |
| ViewModel | **70%** | 状態遷移、入力処理。View に近い部分は除外 OK |
| Repository | **70%** | CRUD + エラーハンドリング |
| Models | テスト不要 | 振る舞いを持たない純粋 struct |
| View | テスト不要 | SwiftUI はユニットテスト非推奨。ロジックは VM に押し出す |

### 80% を超えない理由

100% を追うと ROI が急激に下がる。テストが書きにくい箇所（NotificationCenter のコールバック、Timer、AVAudioSession 等）を無理にテストするより、ビジネスロジックのカバレッジを優先する。

---

## テストピラミッド

```
        /  UI/E2E  \        省略（個人開発。必要になったら追加）
       /  Integration \      ~20%
      /     Unit       \     ~80%
```

| レベル | 対象 | 実行速度 |
|--------|------|---------|
| **Unit** | Service, ViewModel, Repository の純粋ロジック | ~ms |
| **Integration** | SwiftData + Repository の往復、Service 間連携 | ~100ms |
| **UI** | 省略。主要フロー 2-3 本は将来追加を検討 | — |

---

## Given-When-Then の書き方

### 基本構造

```swift
@Test("デフォルト速度を超える値はクランプされる")
func setRate_exceedsMax_clampedToMax() throws {
    // Given
    let repo = MockPlayerStateRepository()
    let sut = PlaybackRateManagerImpl(repo: repo)

    // When
    try sut.setDefaultRate(999.0)

    // Then
    #expect(sut.defaultRate == Constants.MusicPlayer.maxPlaybackRate)
}
```

### ルール

| 項目 | ルール |
|------|-------|
| コメント | `// Given` `// When` `// Then` を必ず書く |
| 命名 | `action_condition_expected()` 形式。例: `setRate_exceedsMax_clampedToMax()` |
| display name | `@Test("日本語で意図を書く")` |
| `#expect` | Then 部分（検証）に使う。失敗しても続行する |
| `#require` | Given 部分（前提条件）に使う。失敗したら即停止。Optional のアンラップに使う |
| `@Suite` | テスト対象の型名。例: `@Suite("PlaybackRateManager Tests")` |

### #expect vs #require の使い分け

```swift
@Test("楽曲をキューに追加する")
func addSongToQueue() throws {
    // Given
    let queue = MusicQueueManager()
    let song = try #require(makeDummySong())  // nil なら即停止（前提条件）

    // When
    let action = await queue.setQueue([song], startAt: 0)

    // Then
    #expect(action == .playNewQueue)      // 失敗しても続行（検証）
    #expect(queue.items.count == 1)       // 複数の検証を一度に確認
    #expect(queue.currentSong?.id == song.id)
}
```

---

## テスト対象の優先順位

### 必ずテストする

- Service の公開メソッド（Protocol で定義されたもの）
- ViewModel の状態遷移（ユーザー操作 → 状態変化）
- 境界値（速度の min/max、キューの空/満杯）
- エラーケース（throws するパス）

### テストしなくてよい

- SwiftUI View の描画
- private メソッド（公開 API 経由で間接的にテストされる）
- Apple フレームワークの振る舞い（MusicKit, MediaPlayer）
- 単純な getter / setter

---

## Mock 方針

- Mock は `Tests/Mock/` に集約
- Protocol ごとに 1 Mock クラス
- Mock の命名: `{Protocol名}Mock`（例: `MusicKitServiceMock`）
- 呼び出し記録: `callCount`, `lastArgs`, `allArgs` の命名規約を統一
- stub の設定: `stub{メソッド名}Result` プロパティ

---

## カバレッジ測定

```bash
# テスト実行 + カバレッジ有効化
xcodebuild test \
  -project Night-Core-Player.xcodeproj \
  -scheme Night-Core-Player \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# レポート表示
xcrun xccov view --report TestResults.xcresult

# JSON 形式で取得
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

Xcode GUI: Product > Test 実行後、Report Navigator (Cmd+9) > Coverage タブ。

---

## 現状の評価と不足

### 現在のテスト状況（218 ケース）

| 対象 | ケース数 | カバレッジ（推定） |
|------|---------|-----------------|
| MusicPlayerServiceImpl + QueueManager | 98 | 高 |
| MusicPlayerViewModel | 60 | 高 |
| MusicKitService | 12 | 中 |
| PlaybackRateManager | 10 | 高 |
| PlayHistoryManager | 10 | 高 |
| PlayerPersistenceService | 8 | 中 |
| SettingsViewModel | 6 | 中 |
| PlaylistViewModel | 6 | 低 |
| SearchViewModel | 5 | 低 |
| PlaylistDetailViewModel | 3 | 低 |

### 不足しているテスト

| 対象 | 不足内容 | 優先度 |
|------|---------|--------|
| SearchViewModel | アーティスト検索、無限スクロール（loadMoreSongsIfNeeded） | 高 |
| ArtistDetailViewModel | load、loadMoreIfNeeded | 高 |
| MusicKitService | searchArtists、fetchArtistTopSongs | 高 |
| MusicKitClient | searchCatalogArtists、fetchArtistTopSongs | 中 |
