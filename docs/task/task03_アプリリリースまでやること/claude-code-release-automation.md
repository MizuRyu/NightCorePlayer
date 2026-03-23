# Claude Code を活用した iOS リリース作業の自動化 — 調査レポート

> 調査日: 2026-03-23
> 対象: Claude Code Agent Skills / Fastlane / App Store Connect 自動化

---

## 1. 概要

iOS アプリのリリースプロセスには、ビルド・署名・メタデータ管理・スクリーンショット生成・審査提出など多くの手作業が伴う。Claude Code の Agent Skills とFastlane を組み合わせることで、これらの大半を自動化できる。

### 参考事例

[ruwatana 氏の記事](https://zenn.dev/ruwatana/articles/claude-code-on-the-web-for-app-development) では、以下をすべて Claude Code で自動化している:
- アプリ名のブレスト・決定
- Bundle ID の一括リネーム
- Node Canvas によるアイコン生成
- デモモード作成 → Simulator スクリーンショット撮影
- 端末モックアップ SVG との合成スクリプト
- Firebase Hosting でプライバシーポリシー・利用規約ページ公開
- GitHub Actions CI/CD
- Firebase Analytics / Crashlytics / Remote Config

> 結果: **約2週間でアイデアからリリースまで完了、初回審査9分で通過**

---

## 2. 利用可能な Claude Code Agent Skills

### 2.1 総合パック: claude-code-apple-skills

**リポジトリ**: [rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills)

Apple プラットフォーム開発向けの包括的なスキル集。iOS / macOS / watchOS / visionOS に対応。

#### 含まれるスキル一覧

| カテゴリ | スキル | 内容 |
|---------|-------|------|
| **Generators** | screenshot-automation | XCUITest / Fastlane でスクショ撮影・加工・一括生成 |
| **App Store** | app-store | メタデータ管理、説明文生成、ASO 最適化 |
| **Release** | release-checklist | リリース前チェックリスト自動生成 |
| **Code Review** | code-review | Swift コードレビュー |
| **Testing** | unit-test-generator | テスト自動生成 |

#### インストール方法

```bash
git clone https://github.com/rshankras/claude-code-apple-skills.git
cp -r claude-code-apple-skills/skills/ your-project/.claude/skills/
```

### 2.2 App Store Release Automator

**URL**: [mcpmarket.com/tools/skills/app-store-release-automator](https://mcpmarket.com/tools/skills/app-store-release-automator)

Fastlane を使ったエンドツーエンドのリリース自動化スキル。

**機能**:
- プリフライトチェック（証明書・プロビジョニング・バージョン確認）
- 自動バージョンバンプ
- ビルド → アーカイブ → 署名
- App Store Connect アップロード
- TestFlight 配布
- 自動リリース設定

### 2.3 fastlane-appstore-release

**URL**: [skills.rest/skill/fastlane-appstore-release](https://skills.rest/skill/fastlane-appstore-release)

Fastlane の `deliver` アクションに特化したスキル。

**機能**:
- メタデータのローカル管理 (`fastlane/metadata/`)
- スクリーンショットの一括アップロード
- バイナリの App Store Connect 送信
- リリースノート管理

### 2.4 App Store Connect Skill

**URL**: [mcpmarket.com/tools/skills/app-store-connect-workflow](https://mcpmarket.com/tools/skills/app-store-connect-workflow)

App Store Connect の操作全般をガイド・自動化。

**機能**:
- ビルド管理（CLI アップロード）
- TestFlight 設定・配布
- メタデータ・スクリーンショット管理
- 審査トラブルシューティング

### 2.5 iOS Release Skill

**URL**: [mcpmarket.com/tools/skills/ios-app-store-release](https://mcpmarket.com/tools/skills/ios-app-store-release)

xcodebuild ワークフローに特化。

**機能**:
- `xcodebuild archive` → IPA エクスポート
- altool / Transporter による ASC アップロード
- TestFlight 配布

### 2.6 MusicKit Audio Skill

**リポジトリ**: [dpearson2699/swift-ios-skills](https://github.com/dpearson2699/swift-ios-skills/blob/main/skills/musickit-audio/SKILL.md)

MusicKit を使った音楽アプリ開発に特化したスキル。

**機能**:
- MusicKit 設定・認証フロー
- Apple Music API 連携
- バックグラウンド再生設定
- エンタイトルメント設定

---

## 3. スクリーンショット生成の自動化（詳細）

### 3.1 方法 A: XCUITest ベース (claude-code-apple-skills)

```
1. UI Test ターゲット作成
2. 各画面のスクショ撮影テスト記述
3. xcrun simctl で各デバイスサイズの Simulator 起動
4. テスト実行 → スクショ自動保存
5. CoreGraphics スクリプトでフレーム + キャプション合成
```

**メリット**: CI に組み込みやすい。デバイス・言語の組み合わせを網羅可能
**デメリット**: XCUITest の学習コスト

### 3.2 方法 B: デモモード + 手動キャプチャ (ruwatana 方式)

```
1. Claude Code にデモモード（モックデータ付き）を作ってもらう
2. Simulator 起動: npm run demo:ios (or xcodebuild)
3. 手動 or xcrun simctl io booted screenshot でキャプチャ
4. 合成スクリプト（Node Canvas / Sharp）で加工
```

**メリット**: シンプル。既存の知識で対応可能
**デメリット**: 手動工程あり

### 3.3 方法 C: Fastlane Snapshot

```
1. Fastlane snapshot セットアップ
2. Snapfile でデバイス・言語指定
3. fastlane snapshot 実行
4. fastlane frameit でフレーム合成
```

**メリット**: 業界標準。ドキュメント豊富
**デメリット**: Ruby 依存。設定が複雑

### 3.4 NightCorePlayer での推奨

**方法 B（デモモード方式）** を推奨:
- プロジェクト規模が小さい
- XCUITest 未導入
- 初回リリースで手早く進めたい

**Claude Code への依頼例**:
```
NightCorePlayer にデモモードを追加して。
- LaunchArgument "-demo" で起動時にモックデータで表示
- 以下の画面のモックデータを用意:
  1. MusicPlayerView（曲再生中、アートワーク表示）
  2. PlaylistView（3つのプレイリスト）
  3. SearchView（検索結果表示）
  4. SettingsView（速度設定 1.3x）
- Simulator でスクショ撮影後、
  scripts/generate-store-screenshots.sh で
  デバイスフレーム + タイトルテキストを合成して
  app-store/screenshots/ に出力
```

---

## 4. Fastlane セットアップ

### 4.1 初期設定

```bash
# Fastlane インストール
brew install fastlane

# プロジェクトで初期化
cd NightCorePlayer
fastlane init
```

### 4.2 推奨 Fastfile 構成

```ruby
default_platform(:ios)

platform :ios do
  desc "Run tests"
  lane :test do
    run_tests(
      project: "Night-Core-Player.xcodeproj",
      scheme: "Night-Core-Player",
      device: "iPhone 16"
    )
  end

  desc "Build for App Store"
  lane :build do
    increment_build_number
    build_app(
      project: "Night-Core-Player.xcodeproj",
      scheme: "Night-Core-Player",
      export_method: "app-store"
    )
  end

  desc "Upload to TestFlight"
  lane :beta do
    build
    upload_to_testflight
  end

  desc "Release to App Store"
  lane :release do
    build
    deliver(
      submit_for_review: true,
      automatic_release: false
    )
  end

  desc "Take screenshots"
  lane :screenshots do
    capture_screenshots
    frame_screenshots
  end
end
```

### 4.3 メタデータ管理

```
fastlane/
├── Appfile                  # App ID, Apple ID
├── Fastfile                 # レーン定義
├── Matchfile                # 証明書管理 (任意)
├── metadata/
│   ├── ja/
│   │   ├── name.txt         # アプリ名
│   │   ├── subtitle.txt     # サブタイトル
│   │   ├── description.txt  # 説明文
│   │   ├── keywords.txt     # キーワード
│   │   └── release_notes.txt
│   └── en-US/
│       ├── name.txt
│       ├── subtitle.txt
│       ├── description.txt
│       ├── keywords.txt
│       └── release_notes.txt
└── screenshots/
    ├── ja/
    │   ├── iPhone 6.9-inch/
    │   ├── iPhone 6.7-inch/
    │   └── iPhone 6.5-inch/
    └── en-US/
```

---

## 5. プライバシーポリシー Web 公開の自動化

### 5.1 GitHub Pages (推奨)

```
docs/
├── index.html              # ランディングページ
├── privacy-policy/
│   └── index.html          # プライバシーポリシー
├── terms/
│   └── index.html          # 利用規約
└── support/
    └── index.html          # サポートページ
```

**GitHub Actions で自動デプロイ**:
```yaml
# .github/workflows/deploy-pages.yml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
    paths: ['docs/**']
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: docs/
      - uses: actions/deploy-pages@v4
```

### 5.2 Firebase Hosting (ruwatana 方式)

Firebase CLI でセットアップ。プレビューデプロイ + 本番自動デプロイが可能。
Analytics / Crashlytics と一緒に導入するなら Firebase がお得。

---

## 6. CI/CD パイプライン

### 6.1 GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.3'
      - name: Build & Test
        run: |
          xcodebuild test \
            -project Night-Core-Player.xcodeproj \
            -scheme Night-Core-Player \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -resultBundlePath TestResults.xcresult
```

### 6.2 Xcode Cloud (Apple 純正)

- Apple Developer Program に含まれる CI/CD
- App Store Connect と直接統合
- TestFlight 自動配布
- 月 25 時間の無料枠

---

## 7. NightCorePlayer 向け自動化ロードマップ

### 即座に対応可能（Claude Code に依頼）

| # | タスク | Claude Code への指示 |
|---|-------|---------------------|
| 1 | Privacy Manifest 作成 | 「PrivacyInfo.xcprivacy を作成して。UserDefaults と Apple App Analytics を宣言」 |
| 2 | Entitlements 作成 | 「MusicKit 用の entitlements ファイルを作成して」 |
| 3 | GitHub Pages セットアップ | 「terms.md をベースに docs/ 以下にプライバシーポリシーと利用規約の HTML を生成して」 |
| 4 | App Store 説明文生成 | 「日英の App Store 説明文・キーワードを生成して fastlane/metadata/ に保存して」 |
| 5 | アイコン生成スクリプト | 「Node Canvas で NightCore をイメージしたアイコンを生成するスクリプトを作って」 |
| 6 | スクショ用デモモード | 「-demo 起動引数でモックデータ表示するデモモードを追加して」 |

### Xcode / Mac 操作が必要

| # | タスク | 備考 |
|---|-------|------|
| 7 | Background Modes 追加 | Xcode の Capabilities で追加（pbxproj 直編集は非推奨） |
| 8 | コード署名 | Xcode で Distribution 証明書を設定 |
| 9 | TestFlight アップロード | `xcodebuild archive` + `altool --upload-app` |
| 10 | App Store Connect 登録 | Web UI での初回アプリ作成 |

---

## 8. 参考リンク

| リソース | URL |
|---------|-----|
| Claude Code Skills ドキュメント | https://code.claude.com/docs/en/skills |
| claude-code-apple-skills | https://github.com/rshankras/claude-code-apple-skills |
| App Store Release Automator | https://mcpmarket.com/tools/skills/app-store-release-automator |
| fastlane-appstore-release | https://skills.rest/skill/fastlane-appstore-release |
| App Store Connect Skill | https://mcpmarket.com/tools/skills/app-store-connect-workflow |
| Fastlane 公式 | https://fastlane.tools/ |
| App Store Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| MusicKit ドキュメント | https://developer.apple.com/musickit/ |
| ruwatana 氏の記事 | https://zenn.dev/ruwatana/articles/claude-code-on-the-web-for-app-development |
| swift-ios-skills (MusicKit) | https://github.com/dpearson2699/swift-ios-skills |
