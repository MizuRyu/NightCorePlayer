# PR 成果物（スクリーンショット・デモ動画）の置き場

- 前提: 自リポジトリの PR 運用規約（UI に変更がある PR はスクショとデモ動画を本文に添付する、という取り決め）。本書はその置き場・埋め込み形式の詳細を定める
- スクショ等の PR 成果物は **main にも feature ブランチにも入れない**（画像を通常のコミット履歴に混ぜると main の肥大化を招くため）。orphan ブランチ `pr-assets`（merge しない）の `pr-<PR番号>/<名前>.png` 配下に置く
- デモ動画の作り方は `scripts/record-demo.sh` のヘッダコメントを参照

## ブランチの構造

```
pr-assets
├── pr-<番号>/          # PR ごとの証跡。一度置いたら動かさない
├── features/
│   ├── <機能>/
│   │   ├── demo.gif    # その機能の最新デモ動画（merge 時に上書き更新）
│   │   ├── demo.mp4
│   │   ├── screens/    # 画面ごとの最新スクショ（画面キー単位で上書き更新）
│   │   └── meta.json   # 索引の生成元（出典 PR・昇格日）
│   └── README.md       # カタログ索引（自動生成）
└── README.md           # ブランチの運用説明（人が書く）
```

- **役割の書き分け**: `pr-<番号>/` は **その PR の証跡**（不変。一度置いたら書き換えない）、`features/` は **機能ごとの最新カタログ**（merge のたびに上書きされる）
- `pr-<番号>/` から `features/` へは **移動ではなくコピー**する。過去 PR の本文が `pr-<番号>/` へのリンクで成り立っているため、移動するとリンクが壊れる
- **自動生成が書き込むのは `features/` 配下だけ**。ルートの `README.md` は人が書くもので、生成スクリプトは触らない

## 埋め込み形式

PR 本文への埋め込みは次の形式を使う:

```
https://github.com/MizuRyu/NightCorePlayer/blob/pr-assets/pr-<番号>/<名前>.png?raw=true
```

- **`raw.githubusercontent.com` への直リンクは使わない**。private リポジトリでは表示されない
- `blob/<branch>/<path>?raw=true` 形式は、ログイン済みメンバーには inline 表示される

### 動画（GIF / mp4）

同じ形式で GIF と mp4 の両方を置き、**GIF をインライン画像、mp4 をリンク**として本文に貼る:

```markdown
![会員が今日の振り返りを保存する](https://github.com/MizuRyu/NightCorePlayer/blob/pr-assets/pr-<番号>/daily-log.gif?raw=true)

[▶ フル解像度の動画（mp4）](https://github.com/MizuRyu/NightCorePlayer/blob/pr-assets/pr-<番号>/daily-log.mp4?raw=true)
```

- GIF は PR 上でぱっと見るための倍速・低解像度版、mp4 は等倍のじっくり確認用。mp4 のリンクは GitHub のファイルビューアが内蔵プレーヤーで再生する
- **mp4 を Markdown でインライン再生させることはできない**。インライン動画になるのは GitHub の Web UI にドラッグ&ドロップして得られる `user-attachments` の URL だけで、そのアップロード API は非公開のため自動化できない（[community#29993](https://github.com/orgs/community/discussions/29993)）。人間がレビュー時に手で貼れば本物のプレーヤーになるので、必要ならそこだけ手動で格上げする

## 機能カタログ（features/）

`pr-assets` ブランチの `features/` を GitHub で開くと索引が描画され、**全機能の最新デモ・画面スクショの一覧**として読める。`features/` 配下は PR が merge されたときに `pr-<番号>/manifest.json` を読んで自動更新される（`.github/workflows/demo-catalog.yml`）。**手で編集しない**（次の merge で上書きされる）。

`manifest.json` は録画スクリプトが生成する。PR に動画を添付するときは、GIF・mp4 と一緒にこれも `pr-<番号>/` に置く（置き忘れると動画は PR に残るがカタログには載らない）。

**動画と `manifest.json` は PR を作る時点で `pr-assets` に push しておく**。カタログの更新は merge 時に走るので、その時点で `pr-<番号>/` が無いと昇格は黙って飛ぶ（エラーにはならない）。取りこぼしたら `demo-catalog` ワークフローを `workflow_dispatch` で PR 番号を指定して再実行すればよい。

### manifest.json の形式

```json
{
  "prNumber": 305,
  "entries": [
    {
      "feature": "daily-log",
      "title": "会員が今日の振り返りを保存すると、一覧に反映される",
      "roles": ["member"],
      "gif": "daily-log.gif",
      "mp4": "daily-log.mp4"
    }
  ],
  "screenshots": [
    {
      "feature": "daily-log",
      "screen": "thread",
      "state": "sent",
      "file": "02-thread-sent.png",
      "caption": "メッセージ送信後のスレッド"
    }
  ]
}
```

- `entries`（動画）は録画スクリプトが書く。`screenshots` は **手で追記してよい**（スクショは手撮り運用なので、録画スクリプトは生成しない）。動画が無い PR では `manifest.json` を手書きしてよい（`entries` を空配列にする）
- `feature` は `[a-z0-9-]+`。`screen` / `state` は `[a-z0-9]+(-[a-z0-9]+)*` で、**連続ハイフン `--` と先頭・末尾のハイフンは使えない**（昇格先の名前を `<screen>--<state>` で組み立てるため、`--` を許すと `screen: "a--b"` と `screen: "a"` + `state: "b"` が同じ画面に潰れて上書きし合う）
- `state` は省略可（`empty` / `error` / `dialog` のような状態を区別したいときだけ付ける）
- `file` は `pr-<番号>/` に置いた実ファイル名（`png` / `jpg` / `jpeg` / `webp`）。`caption` は索引にそのまま出る1行の説明
- `caption` と `title` は**プレーンテキストとして描画される**。Markdown・HTML を書いても記法としては効かず、記号がそのまま表示される（キャプションから索引の構造を壊せないようにするため）

### 動画とスクショの更新単位の違い

- **動画は機能まるごと置き換え**。コピー先は `demo.gif` / `demo.mp4` に固定されるので、元の名前が変わっても孤児は残らない
- **スクショは画面キー単位の上書き**。`features/<機能>/screens/<screen>[--<state>].<拡張子>` へ昇格し、**キーが一致するものだけ**が差し替わる（今回の PR に含まれない画面のスクショはそのまま残る）。同じキーで拡張子が変わったときは旧ファイルを消す
- `meta.json` にはスクショごとの出典 PR と昇格日が入り、索引 `features/README.md` にも出典として描画される。**カタログのスクショの古さは、索引に書かれた出典 PR と日付で判断する**（画像自体には更新日が写らないため）
- 昇格日は「その画像が入れ替わった日」。同じ PR の同じ画像を昇格し直すだけ（`workflow_dispatch` での再実行・push 競合のリトライ）なら据え置かれるので、再実行でカタログが新しく見えることはない

## 運用ルール

- **PR で画面の見た目を変えたら、その画面のスクショを画面キー付きで `manifest.json` の `screenshots` に載せる**。PR 本文に貼るだけでは証跡（`pr-<番号>/`）にしか残らず、カタログは古い見た目のままになる
- **`pr-assets` ブランチは削除しない**。削除すると過去 PR の画像が壊れる
- **feature ブランチ上に画像を置いて参照する方式は使わない**。merge 後にブランチが削除されると PR 上の画像リンクが壊れる
- **`docs/` 配下に PR スクショを置かない**。main に画像が残り続けるため
- 既存の置き場一覧は `pr-assets` ブランチのディレクトリを直接見る（ここに列挙すると陳腐化するため書かない）
