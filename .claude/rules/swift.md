---
paths:
  - "Night-Core-Player/**/*.swift"
  - "Packages/**/*.swift"
---

# swift — 全体の実装規約

構造・依存方向・「やらないこと」の全体像は `docs/specs/ARCHITECTURE.md` を参照（ここでは書かない）。
ここは編集時に踏みやすい制約だけを書く。

- **MUST** `print()` は使わない。`os.Logger`（`Logger(subsystem: Constants.Logging.subsystem, category: "...")`）を使う。
  `disallow_print` custom rule が pre-commit の `--strict` で検出する
- **MUST** Protocol と具象は同じファイルに同居させ、`// MARK: - Protocol` / `// MARK: - Impl` で区切る
  （例外は `MusicPlayerService.swift` / `MusicPlayerServiceImpl.swift` のみ）
- **MUST** View / ViewModel で具象クラスを直接生成しない（`= XXXImpl()` というデフォルト引数は禁止）。
  依存は `App.swift`（Composition Root）で構築し、Constructor Injection で渡す
- **MUST** 新しい Service を追加するときは、どのコンテキスト（Playback / Catalog / Preference /
  Persistence / Monetization）に属するかをファイル先頭のコメントに明記する。
  どれにも属さない場合は新規性を疑う
- **MUST** エラー伝播は `Repository: throws` → `Service: throws + AppError変換` →
  `ViewModel: do-catch → errorMessage: String?` → `View: .alert` の順を守る。View で try/catch を書かない
- **NEVER** `.xcodeproj/project.pbxproj` を手編集しない（hook でブロックされる）。
  新規ファイルは Xcode で追加するか、`bundle exec ruby` で `xcodeproj` gem を使う
