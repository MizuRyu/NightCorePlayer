# task02: 検索履歴保持 (#36)

> 作成日: 2026-03-23
> ステータス: ドラフト（ユーザーレビュー待ち）

---

## 要件

検索キーワードの履歴を保持し、検索画面で表示する。
アーティスト名などで繰り返し検索することが多いため、毎回入力する手間を省く。

---

## 仕様

### 保存対象
- **検索キーワード（テキスト）** を保存する
- 検索が実行された（debounce 後に API コールが発生した）タイミングで保存
- 空白のみのクエリは保存しない

### 永続化
- **UserDefaults** に `[String]` として保存
- キー: `searchHistory`
- 最大 **20 件**。超えた分は古いものから削除
- 同じキーワードの重複は保存しない（既存があれば先頭に移動）

### 表示タイミング
- 検索バーが**空の状態**（`query.isEmpty`）で、かつ検索結果がないとき
- つまり検索画面を開いた直後、またはテキストをクリアした直後

### 表示しないタイミング
- テキスト入力中（検索結果が表示されている）
- ローディング中

---

## UI

### 検索画面の状態遷移

```
┌─────────────────────────────────────────┐
│ 状態1: 初期（query が空）                 │
│                                          │
│ 🔍 [検索バー (空)]                        │
│                                          │
│ 最近の検索                    すべて削除   │
│ ┌──────────────────────────────────────┐ │
│ │ ONE OK ROCK                      ✕  │ │
│ │ 米津玄師                          ✕  │ │
│ │ YOASOBI                          ✕  │ │
│ │ Nightcore                        ✕  │ │
│ └──────────────────────────────────────┘ │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 状態2: 入力中 → 検索結果表示              │
│                                          │
│ 🔍 [ONE OK R...]                         │
│                                          │
│ 🎤 ONE OK ROCK                     >    │
│ 🎵 The Beginning - ONE OK ROCK     ⋮    │
│ 🎵 Wherever you are - ONE OK ROCK  ⋮    │
│ ...                                      │
└─────────────────────────────────────────┘
```

### 履歴行のデザイン

```
┌──────────────────────────────────────────┐
│ キーワードテキスト                     ✕  │
└──────────────────────────────────────────┘
```

- 左: キーワードテキスト
- 右: 個別削除ボタン（`xmark`）
- タップ → そのキーワードで即検索（`query` にセット）

### ヘッダー

```
最近の検索                        すべて削除
```

- 左: 「最近の検索」ラベル
- 右: 「すべて削除」ボタン（タップで全履歴クリア）

---

## データ構造

```swift
// UserDefaults に保存
// key: "searchHistory"
// value: [String]  例: ["ONE OK ROCK", "米津玄師", "YOASOBI"]
```

---

## 変更ファイル

### 新規
なし（既存ファイルへの変更のみ）

### 変更

| ファイル | 変更内容 |
|----------|---------|
| `Features/Search/SearchViewModel.swift` | `searchHistory: [String]` プロパティ追加。検索実行時に履歴保存。履歴の追加/削除/クリアメソッド |
| `Features/Search/SearchView.swift` | 検索バーが空のとき履歴リストを表示。履歴行のUI。タップで即検索 |

### テスト

| ファイル | テスト内容 |
|----------|-----------|
| `SearchViewModelTests.swift` | 履歴追加、重複排除、上限20件、個別削除、全削除、タップ時のクエリ設定 |

---

## 実装方針

### SearchViewModel への追加

```swift
// プロパティ
private(set) var searchHistory: [String] = []
private let historyKey = "searchHistory"
private let maxHistoryCount = 20

// init で UserDefaults から復元
init(musicKitService: MusicKitService) {
    self.musicKitService = musicKitService
    self.searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
}

// 検索実行時に保存（performSearch 内）
private func saveToHistory(_ keyword: String) {
    searchHistory.removeAll { $0 == keyword }
    searchHistory.insert(keyword, at: 0)
    if searchHistory.count > maxHistoryCount {
        searchHistory = Array(searchHistory.prefix(maxHistoryCount))
    }
    UserDefaults.standard.set(searchHistory, forKey: historyKey)
}

// 個別削除
func removeHistoryItem(at index: Int) {
    guard searchHistory.indices.contains(index) else { return }
    searchHistory.remove(at: index)
    UserDefaults.standard.set(searchHistory, forKey: historyKey)
}

// 全削除
func clearHistory() {
    searchHistory.removeAll()
    UserDefaults.standard.removeObject(forKey: historyKey)
}

// 履歴タップ → 即検索
func selectHistoryItem(_ keyword: String) {
    query = keyword
}
```

### SearchView の表示切替

```swift
if vm.isLoading {
    ProgressView()
} else if !vm.artists.isEmpty || !vm.songs.isEmpty {
    // 検索結果リスト（既存）
} else if vm.query.isEmpty && !vm.searchHistory.isEmpty {
    // 検索履歴リスト（新規）
} else {
    Spacer()
}
```

---

## 未確定事項

- [ ] 「すべて削除」タップ時に確認ダイアログを出すか？（Apple Music は出さない）
- [ ] 検索バーの×ボタン（クリア）を追加するか？（現状なし。履歴に戻りやすくするため）
