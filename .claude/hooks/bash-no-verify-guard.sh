#!/usr/bin/env bash
# PreToolUse(Bash) hook。
# git commit / push の --no-verify を禁止する（lefthook ゲートの迂回防止）。
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

[[ -z "$cmd" ]] && exit 0

if [[ "$cmd" == *"--no-verify"* ]] && [[ "$cmd" == *"git "*"commit"* || "$cmd" == *"git "*"push"* ]]; then
  echo "git commit/push --no-verify は禁止。lefthook のゲート（swiftlint --strict / gitleaks / commit-msg / semgrep / trivy）を通すこと。" >&2
  exit 2
fi

exit 0
