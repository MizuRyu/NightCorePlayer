# pr-assets

PR 成果物（スクリーンショット・デモ動画）の置き場。**merge しない・削除しない。**
削除すると過去 PR 本文の画像リンクが全部壊れる。

## 構造

- `pr-<PR番号>/` — その PR の証跡。**一度置いたら書き換えない**
- `features/<機能>/` — 機能ごとの最新カタログ。merge 時に自動更新される（**手で編集しない**。次の merge で上書きされる）
- `features/README.md` — 索引。自動生成

`pr-<番号>/` から `features/` へは移動ではなくコピーされる。過去 PR の本文が `pr-<番号>/` へのリンクで成り立っているため。

## 置き方（iOS）

main 側の `scripts/record-demo.sh` が生成物一式を `demo-output/` に書き出す。

```bash
# シミュレータを1台だけ起動した状態で実行する（複数起動していると録画とテストが別端末に割れる）
SIMULATOR_UDID=<udid> ./scripts/record-demo.sh \
  --feature <slug> --title "<1行説明>" --test <テストメソッド> --pr <PR番号>
```

出力: `<slug>.gif`（倍速・低解像度、PR インライン用）/ `<slug>.mp4`（等倍）/ スクショ PNG / `manifest.json` / `pr-body.md`

このブランチの `pr-<番号>/` へコピーして push し、`pr-body.md` の中身を PR 本文へ貼る。
スクショを機能カタログにも載せる場合は `manifest.json` の `screenshots` に `screen` / `state` / `caption` を手で追記する（録画スクリプトは動画分しか書かない）。

## 埋め込み形式

```
https://github.com/MizuRyu/NightCorePlayer/blob/pr-assets/pr-<番号>/<名前>.png?raw=true
```

`raw.githubusercontent.com` への直リンクは private リポジトリで表示されないため使わない。

## カタログ更新

通常は PR merge 時に `.github/workflows/demo-catalog.yml` が走る。
Actions の実行枠が尽きている間は手元で同じ処理を実行して push する。

```bash
node --experimental-strip-types scripts/build-demo-catalog.ts --assets-dir <このブランチの作業コピー> --pr <番号>
```

運用ルールの詳細は main の `docs/conventions/pr-assets.md`。
