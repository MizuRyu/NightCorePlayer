# AGENTS.md

NightCorePlayer で AI エージェントが作業する際のハブ。各ドキュメントの内容はここに複製せず、
索引だけを置く。

---

## Rules Map

`.claude/rules/*.md` は `paths` の glob に一致するファイルを編集するときに自動で読み込まれる。

| ファイル | 発火する paths | 内容 |
|---|---|---|
| `.claude/rules/swift.md` | `Night-Core-Player/**/*.swift`, `Packages/**/*.swift` | print 禁止 / Protocol+Impl 同居 / DI / エラー伝播 / pbxproj 直編集禁止 |
| `.claude/rules/tests.md` | `**/*Tests.swift` | Swift Testing の書き方、Mock 規約、`sink` + `[weak self]` で VM が早期解放されるテストの罠 |
| `.claude/rules/swiftui.md` | `**/*View.swift` | `@Observable` 注入、List 行内の複数 Button 禁止（過去の同時発火バグ）、アクセシビリティ識別子 |
| `.claude/rules/monetization.md` | `**/Allowance*.swift`, `**/ProStore*.swift`, `**/RewardedAd*.swift` | 残高ゲートは倍速再生のみ / 広告失敗時は無条件付与 / Pro 訴求は生涯1回 |

---

## Docs Map

| ドキュメント | 何が書いてあるか |
|---|---|
| [`docs/specs/ARCHITECTURE.md`](docs/specs/ARCHITECTURE.md) | MVVM + Service Layer の全体構造、ディレクトリ責務、DI ルール、依存方向、「やらないこと」 |
| [`docs/specs/PROJECT-STRUCTURE.md`](docs/specs/PROJECT-STRUCTURE.md) | ディレクトリ構成の詳細（責務は ARCHITECTURE.md 参照） |
| [`docs/specs/PROJECT-RULES.md`](docs/specs/PROJECT-RULES.md) | Issue / ブランチ / コミット / PR の運用フロー、品質ゲートの実行タイミング |
| [`docs/specs/QUALITY-GATES.md`](docs/specs/QUALITY-GATES.md) | 品質ゲート一覧（各ツールの証明対象・実行タイミング）と、意図的に導入していないものとその理由 |
| [`docs/specs/TESTING-STRATEGY.md`](docs/specs/TESTING-STRATEGY.md) | テスト方針、カバレッジ目標、Given-When-Then の書き方、Mock 規約 |
| [`docs/specs/RELEASE.md`](docs/specs/RELEASE.md) | TestFlight 配布〜App Store 審査提出の手順 |
| [`docs/specs/APP-REVIEW-NOTES.md`](docs/specs/APP-REVIEW-NOTES.md) | App Review 情報欄に貼る審査ノート |
| [`docs/specs/RECOMMENDATION.md`](docs/specs/RECOMMENDATION.md) | 自動レコメンド機能の設計（未実装） |
| [`docs/specs/ASO-KEYWORDS.md`](docs/specs/ASO-KEYWORDS.md) | App Store 検索キーワード設計 |
| [`docs/specs/REFACTORING-PLAN-1.2.md`](docs/specs/REFACTORING-PLAN-1.2.md) | 1.2 サイクルのリファクタリング計画（完了記録） |
| [`docs/adr/`](docs/adr/) | 個別の設計判断の記録（ADR）。001: キュー更新の staged 反映 / 002: 速度とピッチの独立制御を公開しない理由 / 003: 残高管理の設計 |

---

## Commands

```bash
make check   # build + lint + swiftformat-lint（コミット前にローカルで通す）
make build   # デバッグビルド
make test    # ユニットテスト（Night-Core-PlayerUITests は除外）
make format  # SwiftFormat で自動整形
make lint    # SwiftLint（--strict なし）

lefthook install   # 初回セットアップ（pre-commit / pre-push / commit-msg フックを有効化）

scripts/record-demo.sh   # UI に変更がある PR 用のデモ動画・スクショ生成
```

品質ゲートの詳細（何が証明され、何が意図的に入っていないか）は
[`docs/specs/QUALITY-GATES.md`](docs/specs/QUALITY-GATES.md) を参照。
