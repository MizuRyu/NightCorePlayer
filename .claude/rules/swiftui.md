---
paths:
  - "**/*View.swift"
---

# swiftui — View 実装の制約

- **MUST** ViewModel は `@Observable`、View からは `@Environment` で注入して受け取る。
  `@EnvironmentObject` は使わない
- **MUST** View は Service を直接持たない。API 呼び出し・状態遷移は ViewModel 経由
- **NEVER** `List` の1行の中に複数の `Button`（またはタップ可能な要素）を並べない。
  行全体のタップジェスチャーと行内ボタンのタップが**同時発火**するバグを過去に踏んでいる。
  行内に操作を複数置きたい場合は `.contentShape` の範囲を絞るか、スワイプアクション /
  コンテキストメニュー（`SongContextMenu` 参照）に寄せる
- **SHOULD** UI テスト（`Night-Core-PlayerUITests`）やデモ録画から要素を特定できるよう、
  操作対象には `.accessibilityIdentifier("snake_case_name")` を付ける
  （例: `mini_player`, `allowance_close_button`）
- **NOTE** View 自体のユニットテストは書かない（ロジックは ViewModel に集約する方針、
  `docs/specs/TESTING-STRATEGY.md` 参照）
