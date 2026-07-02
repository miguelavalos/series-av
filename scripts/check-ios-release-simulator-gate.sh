#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/apps/ios/SeriesAV.xcodeproj"
SCHEME="SeriesAV"
DERIVED_DATA_PATH="${SERIESAV_IOS_RELEASE_SIM_DERIVED_DATA_PATH:-$ROOT_DIR/.derived-data/ios-release-simulator-gate}"
EVIDENCE_DIR="${SERIESAV_IOS_RELEASE_SIM_EVIDENCE_DIR:-$ROOT_DIR/.release-evidence/ios-release-simulator-gate}"
SIMULATOR_NAME="${SERIESAV_IOS_SIMULATOR_NAME:-iPhone 17}"

device_id="${SERIESAV_IOS_SIMULATOR_ID:-}"

if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available | awk -v simulator_name="$SIMULATOR_NAME" '
    index($0, simulator_name " (") {
      if (match($0, /\([0-9A-F-]{36}\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  ')"
fi

if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available | awk '
    /iPhone/ {
      if (match($0, /\([0-9A-F-]{36}\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  ')"
fi

if [[ -z "$device_id" ]]; then
  echo "No available iPhone simulator found." >&2
  xcrun simctl list devices available >&2
  exit 1
fi

mkdir -p "$EVIDENCE_DIR"

echo "==> Series AV iOS release simulator gate"
echo "==> Simulator: $device_id"
echo "==> DerivedData: $DERIVED_DATA_PATH"
echo "==> Evidence: $EVIDENCE_DIR"

echo
echo "==> Public repo hygiene"
vp run config:hygiene

echo
echo "==> Production runtime config preflight"
vp run ios:preflight:production

echo
echo "==> Production API smoke for Search dependencies"
node <<'NODE'
const checks = [
  ["popular", "https://api-series-av.avalsys.com/v1/series/popular?surface=search&locale=es_ES&limit=12"],
  ["search", "https://api-series-av.avalsys.com/v1/series/search?q=Dororo&locale=es_ES&limit=12"],
];

for (const [name, url] of checks) {
  const started = Date.now();
  const response = await fetch(url, { headers: { accept: "application/json" } });
  if (!response.ok) {
    throw new Error(`${name} API smoke failed with HTTP ${response.status}`);
  }
  const body = await response.json();
  if (!Array.isArray(body.results) || body.results.length === 0) {
    throw new Error(`${name} API smoke returned no results`);
  }
  console.log(`${name} API smoke passed (${body.results.length} results, ${Date.now() - started}ms)`);
}
NODE

echo
echo "==> Focused unit and UI tests covering Search, loading state, and shell smoke"
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:SeriesAVTests/SeriesCatalogLoadStateTests \
  -only-testing:SeriesAVTests/SeriesAVAPIClientTests \
  -only-testing:SeriesAVUITests/SeriesAVSmokeUITests/testFollowCatalogSeriesFromSearchAppearsInLibraryAndHome \
  -only-testing:SeriesAVUITests/SeriesAVSmokeUITests/testLocalizedHomeSearchAndLibraryRenderWithLargeDynamicType \
  -only-testing:SeriesAVUITests/SeriesAVSmokeUITests/testLocalizedAccountAndPaywallRenderWithLargeDynamicType

echo
echo "==> Release build with production config"
xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO

app_path="$DERIVED_DATA_PATH/Build/Products/Release-iphonesimulator/SeriesAV.app"
if [[ ! -d "$app_path" ]]; then
  echo "Release simulator app not found: $app_path" >&2
  exit 1
fi

echo
echo "==> Launch Release app on simulator and capture Search evidence"
xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b >/dev/null
xcrun simctl terminate "$device_id" com.avalsys.seriesav >/dev/null 2>&1 || true
xcrun simctl uninstall "$device_id" com.avalsys.seriesav >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app_path"

SIMCTL_CHILD_SERIESAV_UI_TESTS=1 \
SIMCTL_CHILD_SERIESAV_UI_TESTS_FORCE_GUEST=1 \
SIMCTL_CHILD_SERIESAV_UI_TESTS_RESET_STATE=1 \
SIMCTL_CHILD_SERIESAV_UI_TESTS_INITIAL_TAB=search \
SIMCTL_CHILD_SERIESAV_DISABLE_SPLASH=1 \
SIMCTL_CHILD_SERIESAV_DISABLE_ONBOARDING=1 \
  xcrun simctl launch "$device_id" com.avalsys.seriesav \
    -AppleLanguages "(es)" \
    -AppleLocale es_ES >/dev/null

sleep 6
xcrun simctl io "$device_id" screenshot "$EVIDENCE_DIR/search-release-production.png" >/dev/null

echo
du -sh "$DERIVED_DATA_PATH" 2>/dev/null || true
echo "Release Search screenshot: $EVIDENCE_DIR/search-release-production.png"
echo "Series AV iOS release simulator gate passed."
