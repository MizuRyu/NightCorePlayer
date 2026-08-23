#!/usr/bin/env bash
# E2Eデモ録画: DemoUITests をシミュレータで実行しながら録画し、
# GIF（倍速・低解像度、PRインライン用）/ mp4（等倍、確認用）/ スクショPNG /
# manifest.json / pr-body.md を demo-output/ に生成する。
#
# 使い方:
#   scripts/record-demo.sh --feature <slug> --title "<1行説明>" [--test <メソッド名>] [--pr <PR番号>]
#
#   --feature  カタログ上の機能キー [a-z0-9-]+（例: playback-speed）
#   --title    デモの1行説明（索引にそのまま出る）
#   --test     実行するテストメソッド（省略時は DemoUITests 全体）
#   --pr       PR番号。省略時は pr-body.md 内が <PR> のままになる（貼る時に置換）
#
# 生成物の push 先・PR への貼り方は docs/conventions/pr-assets.md を参照。
# CI では動かさない（録画はローカルでオンデマンド）。
set -euo pipefail

SCHEME="Night-Core-Player"
UITEST_TARGET="Night-Core-PlayerUITests"
REPO="MizuRyu/NightCorePlayer"
OUT_DIR="demo-output"
GIF_SPEED=2      # GIFの倍速率
GIF_WIDTH=320    # GIFの横幅(px)
GIF_FPS=8

FEATURE="" TITLE="" TEST="" PR_NUMBER="<PR>"
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift 2 ;;
    --title)   TITLE="$2"; shift 2 ;;
    --test)    TEST="$2"; shift 2 ;;
    --pr)      PR_NUMBER="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
[ -n "$FEATURE" ] || { echo "--feature は必須" >&2; exit 1; }
[ -n "$TITLE" ] || { echo "--title は必須" >&2; exit 1; }
printf '%s' "$FEATURE" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { echo "--feature は [a-z0-9-]+（連続/先頭末尾ハイフン不可）" >&2; exit 1; }

# fail fast: ffmpeg (libx264), python3 (attachment リネーム用)
ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "ffmpeg(libx264) が必要" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 が必要" >&2; exit 1; }

# xcresulttool が書き出した attachment ファイル群を OUT_DIR へコピーするユーティリティ
copy_shots_as_is() {
  local src="$1" dst="$2" n=0 f
  for f in "$src"/*.png "$src"/*.jpeg "$src"/*.jpg; do
    [ -e "$f" ] || continue
    cp "$f" "$dst/$(basename "$f")"
    n=$((n+1))
  done
  echo "スクショ ${n}枚を $dst/ へ抽出（UUID名）"
}

# manifest.json の suggestedHumanReadableName（無ければ displayName / name）へリネームしてコピー。
# manifest 不備・対象0件時は非正常終了する（呼び出し元で UUID 名コピーへフォールバック）
copy_shots_with_manifest_names() {
  python3 - "$1" "$2" <<'PY' || return 1
import json, os, re, shutil, sys

shots_dir, out_dir = sys.argv[1], sys.argv[2]
try:
    with open(os.path.join(shots_dir, "manifest.json")) as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(1)
# xcresulttool のトップレベルはテストごとのリスト。attachments を平坦化する
if isinstance(data, list):
    attachments = [a for item in data for a in item.get("attachments", [])]
else:
    attachments = data.get("attachments", [])

valid_exts = {".png", ".jpg", ".jpeg"}
used = set()
count = 0
for att in attachments:
    exported = att.get("exportedFileName")
    if not exported or not os.path.isfile(os.path.join(shots_dir, exported)):
        continue
    human_name = next(
        (att[k] for k in ("suggestedHumanReadableName", "displayName", "name") if att.get(k)),
        "",
    )
    safe_name = re.sub(r"[^A-Za-z0-9._-]", "-", os.path.basename(human_name))
    stem, ext = os.path.splitext(safe_name)
    ext = ext.lower()
    if ext not in valid_exts:
        payload_ext = os.path.splitext(exported)[1].lower()
        ext = payload_ext if payload_ext in valid_exts else ".png"
    base = f"{stem}{ext}" if stem else f"screenshot-{count + 1}{ext}"
    target, seq = base, 1
    while target in used:
        target = f"{os.path.splitext(base)[0]}-{seq}{ext}"
        seq += 1
    used.add(target)
    shutil.copyfile(os.path.join(shots_dir, exported), os.path.join(out_dir, target))
    count += 1

if count == 0:
    sys.exit(1)
print(count)
PY
}

# シミュレータ選定: SIMULATOR_UDID 優先。無ければ起動済み、それも無ければ利用可能な iPhone を起動
UDID="${SIMULATOR_UDID:-}"
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices booted -j | plutil -extract devices json -o - - 2>/dev/null \
    | grep -oE '"udid" *: *"[A-F0-9-]+"' | head -1 | grep -oE '[A-F0-9-]{36}') || true
fi
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | grep -oE '[A-F0-9-]{36}')
fi
[ -n "$UDID" ] || { echo "シミュレータが見つからない" >&2; exit 1; }
xcrun simctl bootstatus "$UDID" -b >/dev/null

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT_DIR"

# 録画開始（バックグラウンド）→ テスト実行 → SIGINT で録画確定
RAW="$WORK/raw.mov"
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" &
REC_PID=$!
sleep 1

ONLY="$UITEST_TARGET"
[ -n "$TEST" ] && ONLY="$UITEST_TARGET/DemoUITests/$TEST"
XCRESULT="$WORK/demo.xcresult"
set +e
xcodebuild test \
  -project "$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -only-testing:"$ONLY" \
  -resultBundlePath "$XCRESULT" \
  -quiet
TEST_STATUS=$?
set -e
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
[ "$TEST_STATUS" -eq 0 ] || { echo "UIテストが失敗した（録画は $RAW に残っている）" >&2; exit "$TEST_STATUS"; }
[ -s "$RAW" ] || { echo "録画ファイルが空" >&2; exit 1; }

# mp4: 等倍・フル解像度（GitHubのファイルビューアで再生される）
ffmpeg -hide_banner -loglevel error -y -i "$RAW" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  "$OUT_DIR/$FEATURE.mp4"

# GIF: 倍速・低解像度（PRインライン流し見用）。palette 2パスで劣化を抑える
ffmpeg -hide_banner -loglevel error -y -i "$RAW" \
  -vf "setpts=PTS/$GIF_SPEED,fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos,palettegen" "$WORK/palette.png"
ffmpeg -hide_banner -loglevel error -y -i "$RAW" -i "$WORK/palette.png" \
  -lavfi "setpts=PTS/$GIF_SPEED,fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos[x];[x][1:v]paletteuse" \
  "$OUT_DIR/$FEATURE.gif"

# スクショ抽出: テスト内の XCTAttachment(.keepAlways) を xcresult から書き出す。
# export attachments は UUID 名のファイルと manifest.json を出力するので、
# manifest が読めれば XCTAttachment の name へリネームしてコピーする
SHOTS_DIR="$WORK/shots"
mkdir -p "$SHOTS_DIR"
if xcrun xcresulttool export attachments --path "$XCRESULT" --output-path "$SHOTS_DIR" >/dev/null 2>&1; then
  if n=$(copy_shots_with_manifest_names "$SHOTS_DIR" "$OUT_DIR"); then
    echo "スクショ ${n}枚を $OUT_DIR/ へ抽出（XCTAttachment の名前を使用）"
  else
    echo "manifest.json を読めないため UUID 名のままコピーします" >&2
    copy_shots_as_is "$SHOTS_DIR" "$OUT_DIR"
  fi
else
  echo "xcresulttool export attachments が使えないためスクショ抽出をスキップ" >&2
fi

# manifest.json（screenshots はスクショの画面キーが機械決定できないため空。手で追記する）
cat > "$OUT_DIR/manifest.json" <<JSON
{
  "prNumber": ${PR_NUMBER/<PR>/0},
  "entries": [
    {
      "feature": "$FEATURE",
      "title": "$TITLE",
      "roles": [],
      "gif": "$FEATURE.gif",
      "mp4": "$FEATURE.mp4"
    }
  ],
  "screenshots": []
}
JSON

# pr-body.md
BASE="https://github.com/$REPO/blob/pr-assets/pr-$PR_NUMBER"
cat > "$OUT_DIR/pr-body.md" <<MD
![$TITLE]($BASE/$FEATURE.gif?raw=true)

[▶ フル解像度の動画（mp4）]($BASE/$FEATURE.mp4?raw=true)
MD

echo "生成完了: $OUT_DIR/{$FEATURE.gif,$FEATURE.mp4,manifest.json,pr-body.md}"
echo "次: 生成物を pr-assets ブランチの pr-$PR_NUMBER/ へ push し、pr-body.md を PR 本文へ貼る（docs/conventions/pr-assets.md）"
