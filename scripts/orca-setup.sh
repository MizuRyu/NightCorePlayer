#!/usr/bin/env bash
# Orca が worktree 作成時に実行するセットアップ。
# Orca のリポ設定 → Setup script に `bash scripts/orca-setup.sh` を登録して使う。
#
# 目的は「worktree で最初に make test / make build するまでの待ち時間を減らす」こと。
# 秘匿ファイル(.env 等)は環境変数運用のため worktree へコピーしない。
# lefthook は core.hooksPath 経由で全 worktree 共通のため再インストール不要。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[orca-setup] resolve SPM (NightCoreDomain)"
swift package resolve --package-path Packages/NightCoreDomain

echo "[orca-setup] resolve Xcode package dependencies"
xcodebuild -resolvePackageDependencies \
  -project Night-Core-Player.xcodeproj \
  -scheme Night-Core-Player \
  -derivedDataPath ./.derivedData \
  -quiet

echo "[orca-setup] done"
