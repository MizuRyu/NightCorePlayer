# 品質ゲート一覧

> 最終更新: 2026-09-05

各ツールが「何を証明するか」を1つに絞り、証明対象が重複しないようにする（leanbiz の運用に倣う）。
運用フロー自体は [`PROJECT-RULES.md`](./PROJECT-RULES.md) §4 を参照。ここではツールごとの
証明対象・実行タイミングと、意図的に導入していないものの理由を一覧にする。

---

## 導入済み

| ツール | 証明対象 | 実行タイミング |
|---|---|---|
| SwiftLint（`--strict`） | 変更ファイルのコードスタイル・危険な書き方（`disallow_print` 等のカスタムルール含む）。`--strict` は警告もエラー扱い | lefthook pre-commit（staged files のみ）。Claude hooks の PostToolUse でも編集直後に単体実行 |
| SwiftLint（`--strict` なし） | リポジトリ全体のスタイル。既存違反では落ちない | `make check` / `make lint` |
| SwiftFormat（`--lint`） | 整形漏れの検出（自動修正はしない） | `make check`（`check-swiftformat-version` でインストール済みバージョンと `.swiftformat-version` の一致も検査）。Claude hooks の PostToolUse では `--lint` ではなく自動整形を実行 |
| gitleaks（`protect --staged`） | コミットしようとしている差分に秘密情報がないか | lefthook pre-commit |
| gitleaks（`detect --source .`） | リポジトリの全履歴に秘密情報がないか（public 化時点で過去コミットも露出するため差分だけでは不十分） | lefthook pre-push |
| semgrep（`.semgrep/rules.yml`、ローカルルールのみ） | このアプリで実際に起こりうる混入（認証情報の直書き・平文 HTTP・UserDefaults への機密保存・弱いハッシュ）。速度優先で registry は引かない | lefthook pre-push（変更ファイルのみ） |
| trivy（`fs --scanners vuln`） | SPM の解決済み依存（`Package.resolved`）に既知脆弱性がないか | lefthook pre-push |
| commit-msg（Conventional Commits 検証） | コミットメッセージが `<type>(<scope>)?!: <subject>` 形式か | lefthook commit-msg |
| actionlint | GitHub Actions workflow の構文・型エラー | CI（`workflows` job、push / workflow_dispatch） |
| zizmor | GitHub Actions workflow のセキュリティ設定（permissions 過剰、pull_request_target の誤用等） | CI（`workflows` job） |
| xcodebuild test | ビルドが通り、既存テストが壊れていないこと | `make test`（ローカル）、CI（`test` job、**push-to-main のみ**。PR では重いため回さない。マージ前の担保はローカルの `make check`/`make test` と lefthook） |
| Claude hooks（`--no-verify` 禁止 / pbxproj 直編集ガード） | 品質ゲートの迂回・`project.pbxproj` の手編集による破損を、コミット前の時点で防ぐ | Claude Code の PreToolUse（Bash / Write\|Edit） |

---

## 意図的に導入していないもの

| 候補 | 導入しない理由 |
|---|---|
| **jscpd**（コード重複検出） | 汎用トークナイザベースのツールで Swift 特有の重複（Protocol 準拠のボイラープレート、SwiftUI の宣言的な繰り返し）を過検知しやすい。導入には Node/npm ツールチェーンが必要になるが、このリポジトリは Swift 専業でその依存を持ち込む理由がない。50 ファイル規模の個人開発では SwiftLint の `type_body_length` / `cyclomatic_complexity` が複雑化の兆候をすでに拾っており、重複の実害（保守コスト）が顕在化してから再検討する |
| **Periphery**（デッドコード検出） | 導入する。ただし品質ゲート（lefthook / CI の必須チェック）には**しない**。理由は下記「Periphery について」 |
| Muter（ミューテーションテスト） | Issue #70 では「ロジック層限定で要否判断」とされているが、本ドキュメント整備の対象外。別途判断する |

### Periphery について

`swift package plugin periphery scan` でリポジトリ横断の未使用コードを検出できる。個人開発では
リファクタ後の消し忘れ（例: #126 の `MusicPlayerServiceImpl` 分割）が気づかれずに残りやすく、
検出自体には価値がある。一方で、単一ターゲットアプリでも SwiftUI の `@main` / `body` や
Protocol 適合メソッドを未使用と誤検知することがあり、**pre-commit / CI の必須ゲートにすると
偽陽性でブロックされる頻度が割に合わない**。そのため：

- 週次 workflow（`.github/workflows/periphery.yml`）として `schedule` + `workflow_dispatch` で実行
- **失敗させない**（結果は Job Summary に出すのみ。マージや PR をブロックしない）
- 誤検知が多い箇所は `.periphery.yml` の `retain_public` / 個別の `// periphery:ignore` で除外していく運用とし、最初から完璧なチューニングは目指さない
