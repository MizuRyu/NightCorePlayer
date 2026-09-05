#!/usr/bin/env bash
# PreToolUse(Write|Edit) hook。
# project.pbxproj の直接編集を禁止する。手編集は書式崩れ・意図しない設定変更の温床になりやすく、
# このリポジトリは Gemfile 経由で xcodeproj gem（fastlane の依存）を持っている。
# ファイル追加/削除は bundle exec ruby で Xcodeproj::Project を操作するスクリプトを書いて行うこと。
set -euo pipefail

input="$(cat)"
file_path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[[ -z "$file_path" ]] && exit 0

if [[ "$file_path" == *.xcodeproj/project.pbxproj ]]; then
  echo "project.pbxproj の直接編集は禁止。bundle exec ruby で xcodeproj gem（Xcodeproj::Project）を使うこと。例:" >&2
  echo '  bundle exec ruby -e '"'"'require "xcodeproj"; project = Xcodeproj::Project.open("Night-Core-Player.xcodeproj"); ...; project.save'"'"'' >&2
  exit 2
fi

exit 0
