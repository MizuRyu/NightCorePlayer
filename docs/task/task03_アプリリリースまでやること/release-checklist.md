# アプリリリースまでにやること

> 作成日: 2026-03-23
> 対象: NightCore Player (iOS)
> 参考: [Claude Code on the Web でアプリ開発](https://zenn.dev/ruwatana/articles/claude-code-on-the-web-for-app-development)

---

## 目次

1. [最低限やらないといけないこと](#1-最低限やらないといけないこと)
2. [不足している対応事項](#2-不足している対応事項)
3. [Claude Code を活用したリリース作業の自動化](#3-claude-code-を活用したリリース作業の自動化)
4. [このプロジェクトでの入力情報候補](#4-このプロジェクトでの入力情報候補)

---

## 1. 最低限やらないといけないこと

### 1.1 Apple Developer Program

| 項目 | 状態 | 対応内容 |
|------|------|---------|
| Apple Developer Program 登録 | ❓ 要確認 | 年額 ¥15,800。未登録なら登録必須 |
| App ID 登録 | ❓ 要確認 | Developer Portal で MusicKit を有効化した App ID を登録 |
| MusicKit 有効化 | ❓ 要確認 | App ID の Services タブで MusicKit を ON |

### 1.2 Xcode プロジェクト設定（必須）

| 項目 | 現状 | 対応内容 | 優先度 |
|------|------|---------|-------|
| **Entitlements ファイル** | ❌ 未作成 | `.entitlements` ファイル作成、MusicKit capability 追加 | 🔴 必須 |
| **Background Modes** | ❌ 未設定 | `audio` モード追加（バックグラウンド再生に必須） | 🔴 必須 |
| **Privacy Manifest** | ❌ 未作成 | `PrivacyInfo.xcprivacy` 作成（2024年以降の審査で必須） | 🔴 必須 |
| **Release 用 Code Signing** | ⚠️ 自動署名のみ | Distribution 証明書・Provisioning Profile の準備 | 🔴 必須 |
| **Bundle ID 確定** | ⚠️ 仮設定 | `MizuRyu.Night-Core-Player` → 最終版を決定 | 🟡 要判断 |
| **バージョン番号** | `1.0 (1)` | リリース版として適切か確認 | 🟢 OK |

### 1.3 App Store Connect 設定

| 項目 | 対応内容 |
|------|---------|
| **アプリ登録** | App Store Connect で新規 App 作成 |
| **プライバシーポリシーURL** | 公開アクセス可能な URL を用意（GitHub Pages / 独自サイト） |
| **サポートURL** | ユーザーからの問い合わせ先 URL |
| **マーケティングURL** | (任意) アプリ紹介ページ |
| **App Privacy（栄養ラベル）** | 収集データの申告（Apple Analytics のみなら最低限） |
| **年齢制限** | 4+ (音楽再生アプリ、不適切コンテンツなし) |
| **カテゴリ** | 「ミュージック」 |
| **価格** | 無料 |

### 1.4 ストアメタデータ

| 項目 | 対応内容 | 備考 |
|------|---------|------|
| **アプリ名** | 30文字以内。App Store 上での表示名 | [入力候補 →](#41-アプリ名) |
| **サブタイトル** | 30文字以内。簡潔な説明 | |
| **説明文** | 4000文字以内。機能紹介 | |
| **キーワード** | 100文字以内。カンマ区切り | |
| **スクリーンショット** | 最低3枚。6.9" / 6.7" / 6.5" 各サイズ | [自動化 →](#32-スクリーンショット生成の自動化) |
| **App プレビュー動画** | (任意) 最大30秒 | |
| **What's New** | 初回リリースでは不要 | |

### 1.5 審査提出前チェック

- [ ] クラッシュしないことの確認（全画面遷移テスト）
- [ ] Apple Music 未契約ユーザーでの動作確認
- [ ] iPad での表示確認（TARGETED_DEVICE_FAMILY に含まれているため）
- [ ] ネットワーク切断時の動作確認
- [ ] VoiceOver / Dynamic Type の基本的な対応
- [ ] TestFlight での実機テスト

---

## 2. 不足している対応事項

### 2.1 🔴 Critical（審査 Reject の可能性あり）

#### (A) Entitlements ファイルが存在しない

**現状**: `.entitlements` ファイルが未作成。MusicKit は Info.plist の `NSAppleMusicUsageDescription` のみ。

**対応**:
```
Night-Core-Player/Night-Core-Player.entitlements を作成:
- com.apple.developer.musickit = true
```
Xcode の Signing & Capabilities → + Capability → MusicKit で自動追加可能。

#### (B) Background Audio が未設定

**現状**: `UIBackgroundModes` に `audio` が含まれていない。

**影響**: アプリがバックグラウンドに移行すると再生が停止する。**音楽プレイヤーアプリとして致命的**。

**対応**: Xcode → Signing & Capabilities → + Background Modes → Audio, AirPlay, and Picture in Picture をチェック。

#### (C) Privacy Manifest が未作成

**現状**: `PrivacyInfo.xcprivacy` が存在しない。

**影響**: 2024年春以降、Apple は Privacy Manifest を要求。特に NSUserDefaults や System API を使用している場合は必須。

**対応**: `PrivacyInfo.xcprivacy` を作成し、使用している Required Reason API を宣言:
- `NSPrivacyAccessedAPITypes`: UserDefaults 使用の理由等
- `NSPrivacyCollectedDataTypes`: App Analytics データ
- `NSPrivacyTracking`: false
- `NSPrivacyTrackingDomains`: []

#### (D) プライバシーポリシーの公開URL

**現状**: `terms.md` はリポジトリ内にあるが、Web 上で公開されていない。

**影響**: App Store Connect の「プライバシーポリシーURL」は**公開アクセス可能な URL** が必須。

**対応案**:
1. GitHub Pages で公開（最も簡単）
2. 独自ドメインで公開
3. Notion / Google Sites 等で公開

#### (E) 連絡先がダミー値

**現状**: `terms.md` の連絡先が `rmizutani.work@example.com` / `support@example.com`

**影響**: 審査時にサポート連絡先が無効だと Reject。

**対応**: 実際のメールアドレスに更新。

### 2.2 🟡 Important（品質・ユーザー体験に影響）

#### (F) Minimum iOS が 18.4 → 対象ユーザーが極めて限定的

**現状**: `IPHONEOS_DEPLOYMENT_TARGET = 18.4`

**影響**: iOS 18.4 は 2025年3月リリース。多くのユーザーがまだ未アップデート。対象ユーザーが大幅に制限される。

**推奨**: `17.0` まで下げることを検討（`@Observable` は iOS 17+、MusicKit は iOS 15+）。本プロジェクトは既に iOS 17 対応コードで実装済み。

#### (G) AccentColor が未定義

**現状**: `AccentColor.colorset` が存在するが値が空。

**影響**: ボタンやリンクの色がシステムデフォルト（青）のまま。ブランディングの欠如。

**対応**: アプリのテーマカラーを設定。

#### (H) Localization ファイルが未作成

**現状**: `knownRegions` に `ja`, `en` が登録されているが、`.strings` / `.xcstrings` ファイルが存在しない。

**影響**: UI 文字列がハードコードされており、多言語対応ができない。

**対応**: 最低限、日本語（主要）と英語の Localizable.xcstrings を作成。

#### (I) iPad レイアウト未確認

**現状**: `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad)

**影響**: iPad で表示が崩れる可能性。iPad をサポートしないなら `"1"` に変更。

**対応**: iPad レイアウトを確認するか、iPhone のみに変更。

#### (J) Inject フレームワークの除外確認

**現状**: Debug ビルドのみ `Inject` (Hot Reload) を使用。`OTHER_LDFLAGS = -Xlinker -interposable` が Debug のみ。

**確認**: Release ビルドに Inject が含まれないことを確認。含まれる場合、審査で Reject の可能性。

**対応**: `Package.resolved` に Inject が含まれているため、Release ビルドから除外する条件付きリンク設定を確認。

### 2.3 🟢 Nice to Have（将来対応でも可）

| 項目 | 内容 |
|------|------|
| カスタム LaunchScreen | 現在は動的生成。ブランドロゴ付きの LaunchScreen を検討 |
| App Preview 動画 | 30秒のプロモ動画（審査通過率には影響しない） |
| Widget Extension | ミニプレイヤーウィジェット |
| Crashlytics / Analytics | Firebase or Apple Analytics の導入 |
| Remote Config | 強制アップデート通知機能 |
| `any` / `some` の明示 | Swift 6 対応準備 |
| Sendable 準拠 | Swift Concurrency の完全対応 |

---

## 3. Claude Code を活用したリリース作業の自動化

> 詳細調査: [claude-code-release-automation.md](./claude-code-release-automation.md)

### 3.1 利用可能な Agent Skills 一覧

| Skill / ツール | 目的 | ソース |
|---------------|------|-------|
| **[claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills)** | Apple 開発全般のスキル集 | GitHub |
| **[App Store Release Automator](https://mcpmarket.com/tools/skills/app-store-release-automator)** | Fastlane 連携でリリース自動化 | MCP Market |
| **[fastlane-appstore-release](https://skills.rest/skill/fastlane-appstore-release)** | Fastlane App Store リリース | Skills.rest |
| **[App Store Connect Skill](https://mcpmarket.com/tools/skills/app-store-connect-workflow)** | ASC ワークフロー管理 | MCP Market |
| **[iOS Release Skill](https://mcpmarket.com/tools/skills/ios-app-store-release)** | xcodebuild → IPA → ASC | MCP Market |
| **[Screenshot Automation](https://github.com/rshankras/claude-code-apple-skills/blob/main/skills/generators/screenshot-automation/SKILL.md)** | スクショ撮影・加工・一括生成 | GitHub |

### 3.2 スクリーンショット生成の自動化

**参考事例** (ruwatana 氏の方法):
1. **デモモード作成**: モックデータを使った表示用モードを Claude Code に作ってもらう
2. **Simulator でキャプチャ**: `xcrun simctl io booted screenshot` でスクショ取得
3. **合成スクリプト**: 端末モックアップ SVG + タイトル + 背景を合成するスクリプトを生成
4. **一括生成**: ディレクトリにキャプチャを入れるだけで全サイズ生成

**claude-code-apple-skills の方法**:
1. XCUITest でスクショ撮影を自動化
2. CoreGraphics でデバイスフレーム + キャプション合成
3. 全デバイスサイズ × ローカリゼーション一括出力

### 3.3 推奨ワークフロー

```
1. Fastlane セットアップ
   └── Claude Code に Fastfile 作成を依頼
       ├── match: 証明書管理
       ├── gym: ビルド・アーカイブ
       ├── snapshot: スクリーンショット撮影
       ├── deliver: メタデータ・スクショアップロード
       └── pilot: TestFlight 配布

2. スクリーンショット自動生成
   └── Claude Code にデモモード + 合成スクリプト作成を依頼
       ├── scripts/demo-mode.swift
       ├── scripts/generate-screenshots.sh
       └── app-store/screenshots/

3. メタデータ管理
   └── Claude Code に Fastlane metadata ディレクトリ作成を依頼
       ├── fastlane/metadata/ja/description.txt
       ├── fastlane/metadata/ja/keywords.txt
       └── fastlane/metadata/ja/release_notes.txt

4. プライバシーポリシー Web 公開
   └── Claude Code に GitHub Pages セットアップを依頼
       ├── docs/privacy-policy/index.html
       ├── docs/terms/index.html
       └── .github/workflows/deploy-pages.yml

5. CI/CD
   └── Claude Code に GitHub Actions ワークフロー作成を依頼
       ├── .github/workflows/test.yml
       ├── .github/workflows/build.yml
       └── .github/workflows/release.yml
```

### 3.4 このプロジェクトで Claude Code に依頼できること

| タスク | 自動化可能度 | 説明 |
|--------|-----------|------|
| Privacy Manifest 作成 | ✅ 完全自動 | `PrivacyInfo.xcprivacy` のテンプレート生成 |
| Entitlements 作成 | ✅ 完全自動 | `.entitlements` ファイル生成 |
| Background Modes 設定 | ⚠️ 半自動 | pbxproj 編集 or Xcode で手動追加 |
| スクショ用デモモード | ✅ 完全自動 | モックデータ付きプレビューモード作成 |
| スクショ合成スクリプト | ✅ 完全自動 | Node Canvas / Swift スクリプト |
| App Store 説明文 | ✅ 完全自動 | 日本語・英語の説明文生成 |
| キーワード最適化 (ASO) | ✅ 完全自動 | 競合分析に基づくキーワード候補 |
| Fastlane セットアップ | ✅ 完全自動 | Fastfile + Matchfile 生成 |
| GitHub Pages 公開 | ✅ 完全自動 | プライバシーポリシーの Web ページ |
| GitHub Actions CI | ✅ 完全自動 | テスト → ビルド → デプロイ パイプライン |
| アイコン生成 | ✅ 完全自動 | Node Canvas / Swift スクリプト |
| TestFlight 配布 | ⚠️ 半自動 | Fastlane pilot + 手動承認 |
| App Store 提出 | ⚠️ 半自動 | Fastlane deliver + 手動確認 |

---

## 4. このプロジェクトでの入力情報候補

### 4.1 アプリ名

| 項目 | 候補 | 備考 |
|------|------|------|
| **App Store 表示名** | `NightCore Player` | 現在のプロジェクト名ベース |
| | `Nightcore Player` | 一般的な表記 |
| | `NC Player` | 短縮版 |
| **サブタイトル** | `Apple Music を Nightcore で楽しむ` | 日本語版 |
| | `Speed up your Apple Music` | 英語版 |

### 4.2 Bundle ID

| 項目 | 現在値 | 候補 |
|------|-------|------|
| Bundle Identifier | `MizuRyu.Night-Core-Player` | `com.mizuryu.nightcore-player` (逆ドメイン形式推奨) |

### 4.3 App Store Connect メタデータ

| 項目 | 入力候補 |
|------|---------|
| **カテゴリ (Primary)** | ミュージック |
| **カテゴリ (Secondary)** | エンターテインメント |
| **年齢制限** | 4+ |
| **価格** | 無料 |
| **対応地域** | 日本（初回。拡大可能） |
| **言語** | 日本語（主）、英語（副） |

### 4.4 説明文（候補）

#### 日本語

```
NightCore Player は、Apple Music の楽曲を Nightcore スタイルで再生できるプレイヤーアプリです。

▶ 主な機能
・Apple Music ライブラリから楽曲を選択して再生
・再生速度を 0.5x 〜 2.0x で自由に調整
・プレイリストの閲覧・再生
・再生キューの管理
・再生履歴の記録
・ミニプレイヤーでシームレスな操作

▶ Nightcore とは？
楽曲をオリジナルより速いテンポで再生する音楽スタイル。
通常 1.2x 〜 1.5x 程度の速度で再生すると Nightcore 風のサウンドに。

※ Apple Music のサブスクリプションが必要です
```

#### 英語

```
NightCore Player lets you enjoy your Apple Music library in Nightcore style.

▶ Features
・Play songs from your Apple Music library
・Adjust playback speed from 0.5x to 2.0x
・Browse and play your playlists
・Manage your play queue
・Track your listening history
・Mini player for seamless control

▶ What is Nightcore?
A music style that plays songs at a faster tempo than the original.
Try 1.2x - 1.5x speed for that classic Nightcore sound.

※ Requires an Apple Music subscription
```

### 4.5 キーワード（候補）

#### 日本語 (100文字以内)
```
nightcore,ナイトコア,音楽プレイヤー,速度変更,Apple Music,再生速度,倍速再生,プレイリスト,ミュージック,高速再生
```

#### 英語 (100文字以内)
```
nightcore,speed,music player,playback rate,apple music,fast,playlist,tempo,pitch,queue
```

### 4.6 プライバシー関連

| 項目 | 入力値 |
|------|-------|
| **プライバシーポリシーURL** | `https://mizuryu.github.io/NightCorePlayer/privacy-policy` (候補) |
| **サポートURL** | `https://mizuryu.github.io/NightCorePlayer/support` (候補) |
| **サポートメール** | ※ 実際のアドレスに要更新 |
| **収集データ** | 使用状況データ（App Analytics）のみ |
| **トラッキング** | なし |

### 4.7 スクリーンショット要件

| デバイス | サイズ (px) | 必須 |
|---------|-----------|------|
| iPhone 6.9" (16 Pro Max) | 1320 × 2868 | ✅ |
| iPhone 6.7" (15 Plus) | 1290 × 2796 | ✅ |
| iPhone 6.5" (11 Pro Max) | 1284 × 2778 | ✅ |
| iPhone 5.5" (8 Plus) | 1242 × 2208 | ⚠️ iOS 18.4 なら不要 |
| iPad 13" (M4) | 2064 × 2752 | iPad サポート時 |
| iPad 12.9" (6th gen) | 2048 × 2732 | iPad サポート時 |

**最低枚数**: 3枚 / サイズ（最大10枚）

### 4.8 審査用メモ（候補）

```
This app requires an active Apple Music subscription to function.
The app uses MusicKit to access the user's Apple Music library 
and MPMusicPlayerController for playback with rate adjustment.

Test Account: (Apple Music サブスク付きの Apple ID を用意)
```

---

## チェックリスト（実行順）

### Phase 1: プロジェクト設定修正
- [ ] Entitlements ファイル作成 (MusicKit)
- [ ] Background Modes 追加 (Audio)
- [ ] Privacy Manifest 作成
- [ ] Bundle ID の最終決定
- [ ] Minimum iOS バージョンの見直し
- [ ] iPad サポート有無の決定
- [ ] Inject フレームワークの Release 除外確認
- [ ] AccentColor の設定
- [ ] terms.md の連絡先をダミーから実際の値に更新

### Phase 2: ストアアセット準備
- [ ] アプリアイコンの最終版作成
- [ ] スクリーンショット撮影（各デバイスサイズ）
- [ ] 説明文の確定（日本語・英語）
- [ ] キーワードの確定

### Phase 3: Web サイト・法的文書
- [ ] プライバシーポリシーの Web 公開
- [ ] サポートページの作成
- [ ] terms.md の最終確認

### Phase 4: App Store Connect
- [ ] アプリ登録
- [ ] メタデータ入力
- [ ] スクリーンショットアップロード
- [ ] プライバシー情報の入力
- [ ] ビルドアップロード

### Phase 5: テスト・審査
- [ ] TestFlight でのベータテスト
- [ ] 全画面の動作確認
- [ ] 審査提出
- [ ] 審査対応（Reject 時の修正）

---

> 💡 **Tip**: 上記の Phase 1 の大半は Claude Code で自動対応可能。Phase 2 のスクショも自動化スクリプト生成で効率化できる。
