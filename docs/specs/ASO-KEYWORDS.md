# ASO キーワード設計（#74）

## 前提

App Store の検索インデックスは **アプリ名 + サブタイトル + keywords フィールド** の語を統合して作られる。
語はフィールドをまたいで組み合わされるため、**同じ語を複数フィールドに書くのは枠の無駄**になる。
keywords は 100 字（カンマ区切り、スペースは入れない）。

## 狙うクエリ

| クエリ | ロケール | 位置づけ |
|---|---|---|
| nightcore | en-US | 中核。英語圏の検索需要が最も厚い |
| sped up songs / speed up music | en-US | 流入の主力。sped up 文化圏 |
| daycore / slowed | en-US | 低速側。競合が薄く取りやすい |
| pitch shifter / changer | en-US | 機能名での指名検索 |
| 倍速 再生 / 速度変更 | ja | 中核 |
| ナイトコア / デイコア | ja | カタカナ表記の指名検索 |
| ピッチ 変更 / 音程 | ja | 機能名 |

## 配分

### en-US

- **name**: `Night Core Player` — ブランド名。`night` `core` `player` を確保。
  なお "nightcore" の 1 語クエリは name の 2 語分割では確実に拾えないため、keywords 側に単語として置く。
- **subtitle**: `Sped Up & Slowed Music Speed` (28字) — `sped` `up` `slowed` `music` `speed` を確保。
  これで "sped up songs" "speed up music" "slowed music" が name/keywords の語と組み合わせて成立する。
- **keywords** (96字): `nightcore,daycore,pitch,tempo,shifter,changer,song,faster,slower,bpm,audio,gaming,study,chipmunk`
  - name/subtitle と重複する語（player, music, speed, up, sped, slowed）は一切入れない。
  - `song` は単数形のみ。App Store は複数形を自動で拾う。
  - `gaming` `study` は利用シーン検索の受け皿。

### ja

- **name**: `NightCore Player 倍速再生`（既存のまま）— `倍速` `再生` を確保。
- **subtitle**: `どんな曲も自由なテンポで再生`（既存のまま）— `曲` `テンポ` を確保。
- **keywords** (75字): `ナイトコア,速度変更,ピッチ,音楽プレイヤー,スロー,高速,作業用BGM,デイコア,音程,sped up,曲,速さ,bpm,ゲーム,勉強,ダンス,検索`
  - `倍速` `再生` `テンポ` は name/subtitle にあるため除外。
  - 日本語は形態素分割が読めないため、`音楽プレイヤー` `作業用BGM` のように複合語ごと入れる。
  - `sped up` を日本語ロケールにも残す。日本の 10-20 代は英語表記で検索する層がある。
  - `曲` は subtitle と重複するが、`曲 速さ` `曲 速度` の組みを確実にするため 1 語だけ許容。

## 除外した語と理由

- `best` `no.1` 等の最上級 — 根拠のない優位性の主張は審査で落ちる。
- 他社アプリ名・サービス名 — 商標に触れる。Apple Music は連携先として本文で明記する必要があるため例外。
- `free` — 課金モデルが「無料 + 上限 + Pro 買い切り」であり、単独の `free` は誤認を招く。
- `music` を ja keywords に入れること — `音楽プレイヤー` で足りる。

## 更新の判断

- 名称・サブタイトルの変更は審査を伴うため、まず keywords フィールドだけで A/B を回す。
- 効果測定は App Store Connect の「検索」経由インプレッションで見る。
