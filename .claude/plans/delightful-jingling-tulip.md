# docs/ 整理 + README 更新計画

## Context

docs/ に旧ドキュメント（project-guide, design, review）が大量に残っており、現在有効な情報（specs/）と死んだ情報が混在している。ドキュメント構造を整理し、正式な仕様書を大文字ファイル名で統一する。

## 変更一覧

### 1. 削除するもの

| 対象 | 理由 |
|------|------|
| `docs/project-guide/` (13ファイル) | 実装と完全に乖離。ローカルMP4 + AVFoundation 前提の旧仕様 |
| `docs/design/design-docs-v1.md` | 同上 |
| `docs/review/` (13ファイル) | リファクタリング調査・レビュー資料。役割を終えた。必要な内容は specs/ に昇格済み |

### 2. 移動・リネームするもの

| Before | After |
|--------|-------|
| `docs/specs/architecture.md` | `docs/specs/ARCHITECTURE.md` |
| `docs/specs/testing-strategy.md` | `docs/specs/TESTING-STRATEGY.md` |
| `docs/PROJECT-RULES.md` | `docs/specs/PROJECT-RULES.md` |
| `docs/image-guide/001_prompt.md` | `docs/task/task00_アプリアイコン作成/001_prompt.md` |

### 3. 新規作成するもの

| ファイル | 内容 |
|----------|------|
| `docs/specs/PROJECT-STRUCTURE.md` | 現在のソースコードのディレクトリ構造 + 各ディレクトリの責務。ARCHITECTURE.md のディレクトリ構造セクションと重複しない形で、テストディレクトリも含めた全体像 |

### 4. 更新するもの

| ファイル | 変更内容 |
|----------|---------|
| `README.md` | プロジェクト概要を追記（アプリ説明、技術スタック、ディレクトリ構造概要、開発ガイドへのリンク）。既存の Build On Real Device セクションは維持 |
| `docs/specs/ARCHITECTURE.md` | ドメインコンテキストセクションで `docs/review/11-domain-concepts.md` へのリンクを削除（ファイル消去のため） |

### 5. 最終 docs/ 構造

```
docs/
├── specs/                          # 正式な仕様書（大文字ファイル名）
│   ├── ARCHITECTURE.md             # アーキテクチャガイド
│   ├── TESTING-STRATEGY.md         # テスト方針
│   ├── PROJECT-RULES.md            # 運用ルール
│   └── PROJECT-STRUCTURE.md        # ディレクトリ構造（新規）
├── research/                       # 技術調査（参考資料として保持）
│   └── swift-architecture-and-design-patterns.md
└── task/                           # タスク壁打ち
    ├── README.md
    ├── task00_アプリアイコン作成/
    │   └── 001_prompt.md
    ├── task01/
    └── task02_検索履歴/
```

## 実行順序

1. `docs/project-guide/` 削除
2. `docs/design/` 削除
3. `docs/review/` 削除
4. `docs/image-guide/` → `docs/task/task00_アプリアイコン作成/` に移動
5. `docs/specs/` 内ファイルを大文字にリネーム
6. `docs/PROJECT-RULES.md` → `docs/specs/PROJECT-RULES.md` に移動
7. `docs/specs/PROJECT-STRUCTURE.md` 新規作成
8. `docs/specs/ARCHITECTURE.md` の review リンクを修正
9. `README.md` 更新
10. ビルド確認（ドキュメントのみの変更なので壊れないはずだが念のため）

## 検証

- `find docs -type f | sort` で最終構造を確認
- ビルド確認
