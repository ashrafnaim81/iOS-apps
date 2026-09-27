#!/usr/bin/env bash
# Builds the app for the simulator and captures App Store screenshots on a
# 6.9" iPhone and a 13" iPad. Used by .github/workflows/screenshots.yml (macOS only).
set -euo pipefail

OUT="${1:-AppStore/screenshots}"
BUNDLE_ID="com.ashrafnaim.sudoku"
SCENES=(home game daily win achievements)

xcodebuild build \
  -project SudokuGame.xcodeproj -scheme SudokuGame -configuration Debug \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO | xcbeautify || exit "${PIPESTATUS[0]}"
APP=$(find build/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)

# Newest available device whose name matches the pattern.
pick_device() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
pattern = re.compile(sys.argv[1])
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime
           for d in ds if pattern.search(d["name"])]
print(devices[-1]["udid"] if devices else "")' "$1"
}

capture() {
  local label="$1" udid="$2"
  [ -n "$udid" ] || { echo "::warning::No simulator for $label"; return; }
  mkdir -p "$OUT/$label"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  xcrun simctl install "$udid" "$APP"
  local i=1
  for scene in "${SCENES[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshot "$scene" >/dev/null
    sleep 8
    xcrun simctl io "$udid" screenshot "$OUT/$label/$i-$scene.png"
    i=$((i + 1))
  done
  xcrun simctl shutdown "$udid"
}

capture "iphone-6.9" "$(pick_device 'iPhone.*Pro Max')"
capture "ipad-13" "$(pick_device 'iPad Pro.*13')"
ls -R "$OUT"
