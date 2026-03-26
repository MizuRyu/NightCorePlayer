#!/usr/bin/env bash

set -euo pipefail

PROJECT="${PROJECT:-Night-Core-Player.xcodeproj}"
SCHEME="${SCHEME:-Night-Core-Player}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/app-store-screenshots/DerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-build/app-store-screenshots/ja}"
SCREENSHOT_DEVICES="${SCREENSHOT_DEVICES:-iPhone 16 Pro Max|iPhone 16 Plus}"
SCREENSHOT_SCENES="${SCREENSHOT_SCENES:-player,search,playlist,queue}"
LAUNCH_DELAY_SECONDS="${LAUNCH_DELAY_SECONDS:-2}"
STATUS_BAR_TIME="${STATUS_BAR_TIME:-9:41}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/$SCHEME.app"

IFS='|' read -r -a DEVICES <<< "$SCREENSHOT_DEVICES"
IFS=',' read -r -a SCENES <<< "$SCREENSHOT_SCENES"

declare -a BOOTED_UDIDS=()

cleanup() {
  local udid

  for udid in "${BOOTED_UDIDS[@]:-}"; do
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done
}

trap cleanup EXIT

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

find_udid() {
  local device_name="$1"

  xcrun simctl list devices available -j \
    | jq -r --arg name "$device_name" '
      .devices
      | to_entries[]
      | .value[]
      | select(.isAvailable == true and .name == $name)
      | .udid
    ' \
    | head -n1
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

build_app() {
  echo "Building $SCHEME for iOS Simulator..."

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'generic/platform=iOS Simulator' \
    build >/dev/null

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Built app not found: $APP_PATH" >&2
    exit 1
  fi
}

bundle_id() {
  xcodebuild \
    -project "$PROJECT" \
    -target "$SCHEME" \
    -showBuildSettings 2>/dev/null \
    | awk -F ' = ' '/^ *PRODUCT_BUNDLE_IDENTIFIER/ { print $2; exit }'
}

boot_and_prepare() {
  local udid="$1"

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light >/dev/null
  xcrun simctl status_bar "$udid" override \
    --time "$STATUS_BAR_TIME" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null
  xcrun simctl install "$udid" "$APP_PATH" >/dev/null
  BOOTED_UDIDS+=("$udid")
}

capture_scene() {
  local udid="$1"
  local app_bundle_id="$2"
  local scene="$3"
  local destination="$4"

  xcrun simctl terminate "$udid" "$app_bundle_id" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$app_bundle_id" --args \
    -app-store-screenshot-scene "$scene" >/dev/null

  sleep "$LAUNCH_DELAY_SECONDS"
  xcrun simctl io "$udid" screenshot "$destination" >/dev/null
}

require_cmd jq
require_cmd xcodebuild
require_cmd xcrun

mkdir -p "$OUTPUT_DIR"
build_app

APP_BUNDLE_ID="$(bundle_id)"

if [[ -z "$APP_BUNDLE_ID" ]]; then
  echo "Failed to resolve PRODUCT_BUNDLE_IDENTIFIER for $SCHEME" >&2
  exit 1
fi

for device in "${DEVICES[@]}"; do
  if [[ -z "$device" ]]; then
    continue
  fi

  udid="$(find_udid "$device")"

  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $device" >&2
    echo "Available devices:" >&2
    xcrun simctl list devices available | sed 's/^/  /' >&2
    exit 1
  fi

  device_dir="$OUTPUT_DIR/$(slugify "$device")"
  mkdir -p "$device_dir"

  echo "Preparing simulator: $device ($udid)"
  boot_and_prepare "$udid"

  for scene in "${SCENES[@]}"; do
    destination="$device_dir/${scene}.png"
    echo "Capturing $scene on $device -> $destination"
    capture_scene "$udid" "$APP_BUNDLE_ID" "$scene" "$destination"
  done
done

echo
echo "Screenshots generated in: $OUTPUT_DIR"
