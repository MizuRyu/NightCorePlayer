# Night Core Player

Apple Music の楽曲を Nightcore スタイル（高速・高ピッチ）で再生する iOS アプリ。

### What is Night Core?
https://ja.wikipedia.org/wiki/%E3%83%8A%E3%82%A4%E3%83%88%E3%82%B3%E3%82%A2

## Features

- Apple Music カタログからの楽曲・アーティスト検索
- 再生速度のリアルタイム調整（Nightcore 再生）
- プレイリスト表示・再生
- 再生キュー管理
- 再生履歴の記録
- アートワークキャッシュ

## Tech Stack

| 項目 | 技術 |
|------|------|
| 言語 | Swift |
| UI | SwiftUI |
| 最小 OS | iOS 17.0 |
| 音楽 API | MusicKit / MediaPlayer |
| 永続化 | SwiftData |
| アーキテクチャ | MVVM + Service Layer（Protocol-based DI） |
| テスト | Swift Testing |

## Directory Structure

```
Night-Core-Player/          # アプリ本体
├── Core/                   # エラー型、定数
├── Models/                 # 共有データ型
├── Services/               # ビジネスロジック + 外部接続
├── Data/                   # SwiftData 永続化
├── Features/               # 機能単位の View + ViewModel
├── Extensions/             # 型拡張
└── Share/                  # 共有 UI コンポーネント

Night-Core-PlayerTests/     # テスト
docs/specs/                 # 仕様書
```

詳細は [docs/specs/PROJECT-STRUCTURE.md](docs/specs/PROJECT-STRUCTURE.md) を参照。

## Documentation

| ドキュメント | 内容 |
|-------------|------|
| [ARCHITECTURE.md](docs/specs/ARCHITECTURE.md) | アーキテクチャ・設計ルール |
| [TESTING-STRATEGY.md](docs/specs/TESTING-STRATEGY.md) | テスト方針・Mock 規約 |
| [PROJECT-RULES.md](docs/specs/PROJECT-RULES.md) | 運用ルール |
| [PROJECT-STRUCTURE.md](docs/specs/PROJECT-STRUCTURE.md) | ディレクトリ構造 |

## Build On Real Device

接続中の iPhone を使って、VS Code のターミナルからビルド、インストール、起動できます。

### Prerequisites

- iPhone が Mac に接続されていること
- iPhone がアンロックされていること
- iPhone 側で「このコンピュータを信頼」を許可していること
- iPhone 側で Developer Mode を有効化していること
- 初回のみ、必要なら Xcode で `Signing & Capabilities` の署名設定を確認すること

### 1. Connected Device ID を確認

```sh
xcodebuild -showdestinations \
  -project Night-Core-Player.xcodeproj \
  -scheme Night-Core-Player
```

または:

```sh
xcrun xctrace list devices
```

出力された実機の `id` を控える。

### 2. Build

`<DEVICE_ID>` は実機の id に置き換える。

```sh
xcodebuild \
  -project Night-Core-Player.xcodeproj \
  -scheme Night-Core-Player \
  -configuration Debug \
  -destination 'id=<DEVICE_ID>' \
  -derivedDataPath ./.derivedData \
  -allowProvisioningUpdates \
  build
```

### 3. Install To Device

```sh
xcrun devicectl device install app \
  --device <DEVICE_ID> \
  ./.derivedData/Build/Products/Debug-iphoneos/Night-Core-Player.app
```

### 4. Launch

Bundle identifier は `MizuRyu.Night-Core-Player`。

```sh
xcrun devicectl device process launch \
  --device <DEVICE_ID> \
  MizuRyu.Night-Core-Player
```

コンソール付きで起動したい場合:

```sh
xcrun devicectl device process launch \
  --device <DEVICE_ID> \
  --console \
  MizuRyu.Night-Core-Player
```

### Notes

- 接続デバイスが `Connecting` のままなら、ケーブル、信頼許可、Developer Mode を確認する
- 署名エラーが出る場合は、Xcode で一度プロジェクトを開いて team / signing を確認する
- このリポジトリは `Automatic Signing` を前提にしている
