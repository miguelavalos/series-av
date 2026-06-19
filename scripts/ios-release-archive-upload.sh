#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
archive_path=""
build_number=""
version_number=""
upload=0
skip_preflight=0
use_existing_archive=0
team_build_settings=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/ios-release-archive-upload.sh [--build <build>] [--version <version>]
    [--archive <path>] [--upload] [--skip-preflight]

Reproducible Series AV iOS release workflow:
1. validates generated production config unless skipped;
2. creates a signed Xcode archive;
3. verifies bundle id, signing metadata, build, app dSYM, and optional Sentry dSYM;
4. uploads to App Store Connect only when --upload is passed.

Without --upload, this leaves a verified .xcarchive ready for upload.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive)
      archive_path="${2:-}"
      shift 2
      ;;
    --build)
      build_number="${2:-}"
      shift 2
      ;;
    --version)
      version_number="${2:-}"
      shift 2
      ;;
    --upload)
      upload=1
      shift
      ;;
    --skip-preflight)
      skip_preflight=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run_step() {
  echo
  echo "==> $*"
}

plist_set() {
  local key="$1"
  local value="$2"
  local plist="$repo_root/apps/ios/SeriesAV/App/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist"
}

plist_get() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$repo_root/apps/ios/SeriesAV/App/Info.plist"
}

if [ -n "$archive_path" ] && [ -d "$archive_path" ]; then
  use_existing_archive=1
  archive_path="$(cd "$(dirname "$archive_path")" && pwd)/$(basename "$archive_path")"
fi

if [ "$use_existing_archive" -eq 0 ]; then
  if [ -n "$build_number" ]; then
    run_step "Set iOS build number $build_number"
    plist_set "CFBundleVersion" "$build_number"
  fi

  if [ -n "$version_number" ]; then
    run_step "Set iOS marketing version $version_number"
    plist_set "CFBundleShortVersionString" "$version_number"
  fi

  build_number="$(plist_get "CFBundleVersion")"
  version_number="$(plist_get "CFBundleShortVersionString")"
else
  app_info="$archive_path/Products/Applications/SeriesAV.app/Info.plist"
  [ -f "$app_info" ] || { echo "Existing archive app Info.plist is missing: $app_info" >&2; exit 1; }
  if [ -z "$build_number" ]; then
    build_number="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app_info")"
  fi
  if [ -z "$version_number" ]; then
    version_number="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_info")"
  fi
fi

if [ -z "$archive_path" ]; then
  timestamp="$(date '+%Y-%m-%d-%H%M%S')"
  archive_path="$repo_root/.derived-data/release-archives/SeriesAV-${version_number}-${build_number}-${timestamp}.xcarchive"
fi

mkdir -p "$(dirname "$archive_path")"

if [ -n "${SERIESAV_APPLE_TEAM_ID:-}" ]; then
  team_build_settings=(
    "AVALSYS_APPLE_DEVELOPMENT_TEAM=$SERIESAV_APPLE_TEAM_ID"
    "DEVELOPMENT_TEAM=$SERIESAV_APPLE_TEAM_ID"
  )
fi

if [ "$skip_preflight" -eq 0 ] && [ "$use_existing_archive" -eq 0 ]; then
  run_step "Generate production iOS config"
  (cd "$repo_root" && bun run ios:config:production)
  run_step "Run production iOS preflight"
  (cd "$repo_root" && bun run ios:preflight:production)
fi

if [ "$use_existing_archive" -eq 0 ]; then
  run_step "Archive signed iOS release"
  archive_command=(
    xcodebuild archive
    -project "$repo_root/apps/ios/SeriesAV.xcodeproj" \
    -scheme SeriesAV \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates
  )
  if [ "${#team_build_settings[@]}" -gt 0 ]; then
    archive_command+=("${team_build_settings[@]}")
  fi
  "${archive_command[@]}"
else
  run_step "Use existing iOS archive"
  echo "$archive_path"
fi

run_step "Verify final iOS release archive"
"$repo_root/scripts/check-ios-release-archive.sh" \
  --archive "$archive_path" \
  --expected-build "$build_number" \
  --expected-version "$version_number"

if [ "$upload" -eq 1 ]; then
  run_step "Upload verified archive to App Store Connect"
  xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$repo_root/.derived-data/release-uploads/SeriesAV-${version_number}-${build_number}" \
    -exportOptionsPlist "$repo_root/apps/ios/Config/ExportOptionsUpload.plist" \
    -allowProvisioningUpdates
else
  cat <<REPORT

Verified archive is ready.
  archive: $archive_path

To upload this exact archive, rerun:
  bun run ios:release:upload -- --archive "$archive_path" --upload --skip-preflight
REPORT
fi
