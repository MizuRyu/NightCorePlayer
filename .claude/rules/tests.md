---
paths:
  - "**/*Tests.swift"
---

# tests — テストの書き方

方針・カバレッジ目標・優先順位は `docs/specs/TESTING-STRATEGY.md` を参照（ここでは書かない）。

- **MUST** Swift Testing（`@Test`, `#expect`, `#require`）を使う。XCTest は使わない
- **MUST** Given-When-Then で書き、`// Given` `// When` `// Then` コメントを必ず入れる
- **MUST** テスト名は `action_condition_expected()` 形式、`@Test("日本語で意図を書く")` を添える
- **MUST** Mock は `Night-Core-PlayerTests/Mock/`（Domain 側は `NightCoreDomainTestSupport`）に置く。
  命名は `{Protocol名}Mock`。呼び出し記録は `callCount` / `lastArgs` / `allArgs`、
  stub は `stub{メソッド名}Result` の命名規約に合わせる
- **既知の罠（このリポジトリで複数回踏んでいる）**: ViewModel の `Combine.sink` は
  `[weak self]` でキャプチャする実装が多い。テストの `sut`（ViewModel）をローカル変数のまま
  早期に破棄させたり、参照を保持せず publisher の発火を待つと、発火前に `self` が
  `nil` になりコールバックが実行されずテストが無言で失敗（何も検証されず pass に見える、
  または期待値が更新されず落ちる）する。**テスト関数のスコープ内で `sut` を最後まで
  強参照し続けること**（弱参照だけの変数に代入しない、`sut = nil` を検証前に書かない）
