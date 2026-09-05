#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook。
# 編集直後に swiftformat → swiftlint をかけ、違反が残っていれば exit 2 で stderr をモデルに返す。
# 修正は書いた直後が一番安いという方針（leanbiz の biome-on-edit.ts と同じ発想）。
#
# swiftformat / nix がローカルに無い環境でもこの hook 自体は壊さない（fallback して exit 0）。
set -euo pipefail

# UTF-8以外のロケールだと変数展開直後の日本語がbashの識別子解析を壊すことがある(実測)ため固定する
export LC_ALL=en_US.UTF-8

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$project_dir"

input="$(cat)"
file_path="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' <<<"$input")"

[[ -z "$file_path" ]] && exit 0
[[ "$file_path" != *.swift ]] && exit 0
[[ -f "$file_path" ]] || exit 0

# パスをリポジトリルートからの相対パスに正規化（swiftlint の nested config 解決のため）
case "$file_path" in
  "$project_dir"/*) rel_path="${file_path#"$project_dir"/}" ;;
  /*) rel_path="$file_path" ;;
  *) rel_path="$file_path" ;;
esac

expected_version="$(cat .swiftformat-version 2>/dev/null || true)"

swiftformat_cmd=()
if command -v swiftformat >/dev/null 2>&1 && [[ "$(swiftformat --version 2>/dev/null)" == "$expected_version" ]]; then
  swiftformat_cmd=(swiftformat)
elif command -v nix >/dev/null 2>&1; then
  swiftformat_cmd=(nix shell nixpkgs#swiftformat --command swiftformat)
fi

if [[ ${#swiftformat_cmd[@]} -eq 0 ]]; then
  echo "swift-format-lint-on-edit: swiftformat が見つからない（.swiftformat-version=${expected_version}）。整形をスキップします。" >&2
else
  "${swiftformat_cmd[@]}" "$rel_path" >/dev/null 2>&1 || true
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swift-format-lint-on-edit: swiftlint が見つからない。lint をスキップします。" >&2
  exit 0
fi

lint_output="$(swiftlint lint --strict "$rel_path" 2>&1)"
lint_status=$?

if [[ $lint_status -ne 0 ]]; then
  echo "swiftlint 違反（このファイルを直してから続行）:" >&2
  echo "$lint_output" | tail -c 3000 >&2
  exit 2
fi

exit 0
