# task02: 実装計画

> 作成日: 2026-03-23
> 前提: spec.md

---

## 実装順序

### Step 1: SearchViewModel に履歴機能追加

- `searchHistory: [String]` プロパティ
- `init` で UserDefaults から復元
- `saveToHistory()` — 検索実行時に呼ぶ
- `removeHistoryItem(at:)` — 個別削除
- `clearHistory()` — 全削除
- `selectHistoryItem()` — query にセットして即検索

### Step 2: SearchView に履歴表示 UI

- query が空 & 検索結果なし & 履歴あり → 履歴リスト表示
- ヘッダー（「最近の検索」+「すべて削除」）
- 履歴行（時計アイコン + キーワード + 個別削除）
- タップで即検索

### Step 3: テスト

- 履歴追加（検索実行後に保存される）
- 重複排除（同じキーワードは先頭に移動）
- 上限20件
- 個別削除
- 全削除
- selectHistoryItem で query が更新される

---

## 影響範囲

- `SearchViewModel.swift` — メイン変更
- `SearchView.swift` — UI 追加
- `SearchViewModelTests.swift` — テスト追加
- 他ファイルへの影響なし
