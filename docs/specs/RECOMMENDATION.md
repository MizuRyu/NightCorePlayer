# 自動レコメンド設計 — Nightcore Daily

> 最終更新: 2026-08-29
> 状態: 設計 (未実装)。API 事実は 2026-08-29 の MusicKit 公式ドキュメント調査に基づく

---

## 目的

「聴く曲を毎回自分で探す」手間をなくす。ユーザーの聴取実績から毎日20曲の自動キューを生成し、1タップで倍速再生を開始できるようにする。

現行の `MusicKitServiceImpl.fetchPersonalRecommendations` は自分のライブラリプレイリストをシャッフルするだけの暫定実装であり、本設計はその本実装化を兼ねる。

## 方針

**C: 履歴ベース 7割 + D: 類似探索 3割** の配合で「安心して流せる曲」と「聴いたことがないが刺さりそうな曲」を混ぜる。

```
ソース収集
  ├─ ローカル再生履歴 (PlayHistoryManager)     … 頻度の重み付けに使う
  └─ MusicRecentlyPlayedRequest<Song>          … アプリ外の聴取も拾う
        ↓
頻度上位アーティスト抽出 (上位5組)
        ↓
  ├─ C (14曲): 履歴の高頻度曲 + 上位アーティストの topSongs
  └─ D (6曲):  上位アーティストの similarArtists → topSongs
               既知曲 (履歴にある曲) は除外
        ↓
重複除去 → シャッフル → 20曲
```

## 使用 API (調査済みの事実)

| 用途 | API | 制約 |
|---|---|---|
| 最近の再生曲 | `MusicRecentlyPlayedRequest<Song>` (iOS 16+) | Music User Token 必須。件数上限は公式記載なし (30件で頭打ちのフォーラム報告あり) |
| 類似アーティスト | `artist.with(.similarArtists)` | 類似は Artist 単位のみ。`similarSongs` は存在しない |
| アーティスト代表曲 | 既存 `fetchArtistTopSongs` | — |

**不採用**: REST `/v1/me/history/heavy-rotation`(空配列が返る不具合報告が複数、MusicKit Swift 型も存在しない)。「よく聴く」の判定はローカル履歴の頻度集計で代替する。

## 構成 (MVVM + Service 流儀に合わせる)

- **`RecommendationService` (Protocol + Impl) を新設**: 配合アルゴリズムの持ち場。`MusicKitClient` と `PlayHistoryManaging` に依存
- **`MusicKitClient` に primitive を追加**:
  - `fetchRecentlyPlayedSongs(limit:) async throws -> [Song]`
  - `fetchSimilarArtists(artist:) async throws -> [Artist]`
- **`MusicKitService.fetchPersonalRecommendations` は `RecommendationService` へ委譲**に置き換え、呼び出し元 (MusicPlayerServiceImpl) の署名は変えない

## 生成タイミングとキャッシュ

- 日次生成: 同日中はメモリキャッシュ (actor 内) を再利用。アプリ再起動で再生成
- 永続化キャッシュは見送り (曲IDから Song を復元する catalog fetch primitive が追加で必要になるため。必要になったら別 issue)

## フォールバック (fail-soft)

非サブスク・未認証・API エラー時の挙動は公式仕様が未確認のため、段階的に落とす:

1. MusicKit 履歴が取れない → ローカル履歴のみで生成
2. similarArtists が空/エラー → C を10割に
3. ローカル履歴も空 (新規ユーザー) → 現行実装 (ライブラリシャッフル) をそのまま流用

## テスト

`RecommendationService` をモック `MusicKitClient` + モック履歴でユニットテスト:

- 配合比率 (C/D = 14/6) と総数20の保証
- D 系から既知曲が除外されること
- フォールバック3段の分岐
- 履歴が極端に少ない場合の縮退 (20曲に満たなくても壊れない)

## 非目標

- サーバサイドのレコメンドエンジン
- BPM・音響解析による選曲 (MusicKit にテンポ情報がないため)
- heavy-rotation REST の利用
- iOS 27 Beta の新 API (`PickableMusicItem` 等) への依存

## 参考

- [MusicRecentlyPlayedRequest](https://developer.apple.com/documentation/musickit/musicrecentlyplayedrequest)
- [Artist.similarArtists](https://developer.apple.com/documentation/musickit/artist/similarartists)
- [MusicPropertyContainer](https://developer.apple.com/documentation/musickit/musicpropertycontainer)
