# Night Core Player

### What is Night Core ?
https://ja.wikipedia.org/wiki/%E3%83%8A%E3%82%A4%E3%83%88%E3%82%B3%E3%82%A2

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
