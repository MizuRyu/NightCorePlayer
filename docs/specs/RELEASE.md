# リリース手順

TestFlight への配布から App Store 審査提出までの手順。
審査ノートの本文とチェックリストは [APP-REVIEW-NOTES.md](APP-REVIEW-NOTES.md) を参照。

## 前提: App Store Connect API キー

`fastlane beta` / `fastlane submit_for_review` は App Store Connect API キーを使う。
Apple ID とパスワードによる認証は 2FA の対話が入るため使わない。

### キーの発行

1. App Store Connect → **ユーザとアクセス** → **統合** → **App Store Connect API**
2. **チームキー**タブで「+」を押し、アクセス権に **App Manager** を指定して生成
3. `AuthKey_XXXXXXXXXX.p8` をダウンロード（**再ダウンロードできない**ため必ず保管する）
4. 同じ画面から **Key ID** と **Issuer ID** を控える

### 環境変数の設定

`.p8` は base64 に変換して渡す。Fastfile が `is_key_content_base64: true` で受け取る。

```sh
export ASC_KEY_ID="発行した Key ID"
export ASC_ISSUER_ID="発行した Issuer ID"
export ASC_KEY_CONTENT="$(base64 -i ~/path/to/AuthKey_XXXXXXXXXX.p8)"
export APPLE_ID="Apple ID のメールアドレス"
```

`.p8` と各 ID は秘密情報のため、リポジトリに置かない。
`.gitignore` は `*.p8` と `.env` を除外済みだが、そもそも置かない運用にする。

## TestFlight へ配布 (#76)

```sh
bundle exec fastlane beta
```

`beta` は内部で `build` を実行してから `pilot` でアップロードする。
配布先は Internal グループ。リリースノートは `RELEASE_NOTE` で上書きできる。

```sh
RELEASE_NOTE="残高まわりの修正を確認" bundle exec fastlane beta
```

### アップロード前の自己検証

認証を通す前に、アーカイブが成立するかだけ確認できる。

```sh
xcodebuild -project Night-Core-Player.xcodeproj \
  -scheme Night-Core-Player \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/NightCorePlayer.xcarchive \
  -allowProvisioningUpdates archive
```

成果物の確認ポイント。

```sh
P=build/NightCorePlayer.xcarchive/Products/Applications/Night-Core-Player.app

codesign -dv "$P"                                        # 署名と Team ID
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$P/Info.plist"
ls "$P/PrivacyInfo.xcprivacy"                            # AdMob / ATT に必須

# デバッグ機能が Release に漏れていないこと
strings "$P/Night-Core-Player" | grep -c debugExhaust    # 0 であること
```

## TestFlight で確認すること (#76)

デバッグ入口は Release ビルドに含まれないため、通常の経路でしか到達できない。

- [ ] リワード広告が**本番ユニット ID**で表示される（Debug はテスト ID のため別物）
- [ ] 広告視聴後に +30 分が付与され、残り再生時間の表示に反映される
- [ ] 視聴後に再生が自動復帰する
- [ ] 残高が尽きたとき、曲の途中で切れず曲末で停止する
- [ ] Pro を購入でき、購入後に無制限になる
- [ ] 「購入を復元」が機能する
- [ ] リワード累計 5 回で Pro 訴求が 1 回だけ出る

残高の枯渇には 1 日分の無料枠 3600 秒を消費する必要がある。
トライアル中（初回起動から 7 日間）は枯渇しないため、テスターに配る前に
トライアルが明けた端末を用意するか、消費してから確認する。

## 審査提出 (#77)

初回の非消耗型アプリ内課金は、**アプリのバージョンと同時に提出する**必要がある。

1. App Store Connect → アプリ内課金 → Pro → **「審査用に追加」**
2. 課金の「審査に関する情報」にスクリーンショットを添付
   （`scripts/` で生成したダイアログのスクリーンショット）
3. バージョン情報にスクリーンショット・説明文・URL を設定
   （メタデータは `fastlane/metadata/` にあり `deliver` で反映できる）
4. App Review 情報のメモに [APP-REVIEW-NOTES.md](APP-REVIEW-NOTES.md) の本文を貼る
5. 提出

```sh
bundle exec fastlane submit_for_review
```

## 段階的公開 (#78)

審査通過後、App Store Connect のバージョンリリース設定で
**段階的リリース**を有効にしてから公開する。

公開後に監視する項目。

- クラッシュ率（Xcode Organizer / App Store Connect のメトリクス）
- リワード広告の表示・完了率（AdMob 管理画面）
- Pro の購入数と復元の失敗（App Store Connect の売上とトレンド）
