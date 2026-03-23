# NightCorePlayer 運用ルール

> 最終更新: 2026-03-23

---

## ワークフロー概要

```
アイデア / バグ発見
    ↓
[task/ で壁打ち]（任意。仕様が曖昧な場合）
    ↓
Issue 作成（gh issue create）
    ↓
ブランチ作成（Issue から）
    ↓
実装 + テスト
    ↓
PR 作成（gh pr create）
    ↓
レビュー + マージ
    ↓
ブランチ削除
```

---

## 1. Issue 管理

### Issue の作り方

```bash
# 機能追加
gh issue create --title "アーティスト検索&再生機能" --label "enhancement" --body "## 概要
検索結果にアーティストも表示し、タップで楽曲一覧を開く

## やること
- [ ] MusicKitService にアーティスト検索 API 追加
- [ ] 検索結果 UI の更新
- [ ] アーティスト詳細画面の追加"

# バグ修正
gh issue create --title "スライダーの値が正しく反映されない" --label "bug" --body "## 再現手順
1. Player 画面でスライダーを操作
2. 値が意図しない値になる

## 期待する動作
スライダーの位置に対応した速度が設定される"

# リファクタリング
gh issue create --title "MusicPlayerServiceImpl の責務分割" --label "refactor" --body "## 背景
757行の God Object を分割する"
```

### Issue のルール

- **1 Issue = 1 関心事**。複数の機能を1つの Issue に詰め込まない
- Issue 番号がブランチ名・PR に紐づく
- ラベル: `enhancement`（機能追加）, `bug`（バグ）, `refactor`（リファクタ）
- 仕様が固まっていなくてもOK。先に Issue を作り、仕様は後から `docs/task/` で整理

### 既存 Issue の確認

```bash
gh issue list                    # 一覧
gh issue view 34                 # 詳細
gh issue list --label "bug"      # ラベル絞り込み
```

---

## 2. ブランチ戦略

### ブランチ命名

```
<type>/<issue番号>-<短い説明>
```

| type | 用途 | 例 |
|------|------|-----|
| `feature/` | 新機能 | `feature/34-artist-search` |
| `fix/` | バグ修正 | `fix/45-slider-rate-bug` |
| `refactor/` | リファクタリング | `refactor/50-service-split` |

### ブランチ作成

```bash
# Issue から直接ブランチ作成
gh issue develop 34 --name "feature/34-artist-search" --base main

# または手動
git checkout main
git pull origin main
git checkout -b feature/34-artist-search
```

### ルール

- **main から切る**（他の feature ブランチから切らない）
- **1ブランチ = 1 Issue = 1 PR**
- 作業が終わったらマージ後にブランチ削除
- 長期間マージされないブランチは定期的に main を取り込む

---

## 3. コミット

### コミットメッセージ

```
<type>: <変更内容の要約>

<詳細（任意）>
```

| type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | リファクタリング（機能変更なし） |
| `test` | テスト追加/修正 |
| `docs` | ドキュメント |
| `chore` | 雑務（CI, 設定等） |

例:
```
feat: アーティスト検索機能を追加
fix: スライダーが absolute value を delta として扱うバグを修正
refactor: MusicPlayerServiceImpl から PlaybackRateManager を抽出
```

### ルール

- 1コミットは1つの論理的変更
- ビルドが通る状態でコミットする
- WIP コミットは PR マージ時にスカッシュ

---

## 4. PR（Pull Request）

### PR 作成

```bash
gh pr create --title "feat: アーティスト検索&再生機能 #34" --body "$(cat <<'EOF'
## Summary
- 検索結果にアーティストを追加（混在リスト）
- アーティスト詳細画面を追加（topSongs 表示）
- 再生 / シャッフル機能

## Related Issue
Closes #34

## Test plan
- [ ] アーティスト検索が動作する
- [ ] アーティスト詳細で楽曲一覧が表示される
- [ ] 楽曲タップで再生開始する
- [ ] 全テスト green
EOF
)"
```

### PR のルール

- **タイトルに Issue 番号を含める**（`#34`）
- **`Closes #XX`** で Issue を自動クローズ
- Squash merge を基本とする（`gh pr merge --squash`）
- マージ後にブランチ自動削除

### マージ

```bash
gh pr merge --squash --delete-branch
```

---

## 5. task/ ディレクトリの使い方

仕様が曖昧な場合、Issue を切る前に `docs/task/` で壁打ちする。

```
docs/task/
├── task01/
│   ├── todo.txt                # ユーザーの要望（入力）
│   ├── spec.md                 # 仕様ドラフト
│   ├── implementation-plan.md  # 実装計画
│   └── research_xxx.md         # 調査結果
├── task02/
└── README.md
```

### フロー

1. `todo.txt` にやりたいことを書く
2. 調査・仕様検討を行い `spec.md` 等を作成
3. ユーザーレビューで方針が固まる
4. **Issue を作成**し、ブランチを切って実装に入る
5. 仕様が確定したら `docs/specs/` に昇格（任意）

---

## 6. よく使う gh コマンド

```bash
# --- Issue ---
gh issue list                           # 一覧
gh issue create --title "..." --label "enhancement"  # 作成
gh issue view 34                        # 詳細
gh issue close 34                       # クローズ
gh issue develop 34 --name "feature/34-xxx"  # ブランチ作成

# --- PR ---
gh pr create --title "..." --body "..."  # 作成
gh pr list                              # 一覧
gh pr view 5                            # 詳細
gh pr merge --squash --delete-branch    # マージ

# --- Branch ---
gh pr checkout 5                        # PR のブランチに切替
```

---

## 7. やらないこと

- GitHub Projects / Milestones は使わない（個人開発では過剰）
- CI/CD はまだ設定しない（App Store 公開時に検討）
- 厳密なリリースタグ管理はしない（リリース前のため）
