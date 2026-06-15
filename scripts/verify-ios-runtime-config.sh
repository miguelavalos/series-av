#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-local}"
configuration="${2:-Debug}"

case "$profile" in
  local)
    expected_bundle_identifier="com.avalsys.seriesav.dev"
    expected_key_prefix="pk_test_"
    expected_revenuecat_key_prefix="appl_"
    expected_api_base_url="http://127.0.0.1:8788"
    expected_series_api_base_url="http://127.0.0.1:8791"
    expected_keychain_access_group="935PM55U6R.com.avalsys.seriesav.dev"
    expected_management_host="account-av-preview.avalsys.com"
    ;;
  preview)
    expected_bundle_identifier="com.avalsys.seriesav.dev"
    expected_key_prefix="pk_test_"
    expected_revenuecat_key_prefix="appl_"
    expected_api_base_url="https://api-account-av-preview.avalsys.com"
    expected_series_api_base_url="https://api-series-av-preview.avalsys.com"
    expected_keychain_access_group="935PM55U6R.com.avalsys.seriesav.dev"
    expected_management_host="account-av-preview.avalsys.com"
    ;;
  production)
    expected_bundle_identifier="com.avalsys.seriesav"
    expected_key_prefix="pk_live_"
    expected_revenuecat_key_prefix="appl_"
    expected_api_base_url="https://api-account-av.avalsys.com"
    expected_series_api_base_url="https://api-series-av.avalsys.com"
    expected_keychain_access_group="935PM55U6R.com.avalsys.seriesav"
    expected_management_host="account-av.avalsys.com"
    configuration="Release"
    ;;
  *)
    echo "Usage: $0 local|preview|production [Debug|Release]" >&2
    exit 2
    ;;
esac

local_config="$repo_root/apps/ios/Config/Local.xcconfig"
if [ ! -f "$local_config" ]; then
  echo "Missing $local_config. Run bun run ios:config or bun run ios:config:production first." >&2
  exit 1
fi

settings="$(
  xcodebuild \
    -project "$repo_root/apps/ios/SeriesAV.xcodeproj" \
    -scheme SeriesAV \
    -configuration "$configuration" \
    -destination 'generic/platform=iOS Simulator' \
    -showBuildSettings 2>/dev/null
)"

setting_value() {
  local key="$1"
  printf '%s\n' "$settings" \
    | awk -F ' = ' -v key="$key" '$1 ~ "^[[:space:]]*" key "$" { value=$2 } END { print value }'
}

failures=0

expect_value() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [ "$actual" != "$expected" ]; then
    printf 'Mismatch: %s\n  expected: %s\n  actual:   %s\n' "$label" "$expected" "${actual:-<empty>}" >&2
    failures=$((failures + 1))
  fi
}

expect_prefix() {
  local label="$1"
  local actual="$2"
  local expected_prefix="$3"

  if [[ "$actual" != "$expected_prefix"* ]]; then
    printf 'Mismatch: %s must start with %s. Actual value is hidden.\n' "$label" "$expected_prefix" >&2
    failures=$((failures + 1))
  fi
}

expect_value "PRODUCT_BUNDLE_IDENTIFIER" "$(setting_value PRODUCT_BUNDLE_IDENTIFIER)" "$expected_bundle_identifier"
expect_prefix "ACCOUNTAV_PUBLISHABLE_KEY" "$(setting_value ACCOUNTAV_PUBLISHABLE_KEY)" "$expected_key_prefix"
expect_value "ACCOUNTAV_KEYCHAIN_ACCESS_GROUP" "$(setting_value ACCOUNTAV_KEYCHAIN_ACCESS_GROUP)" "$expected_keychain_access_group"
expect_prefix "SERIESAV_REVENUECAT_PUBLIC_API_KEY" "$(setting_value SERIESAV_REVENUECAT_PUBLIC_API_KEY)" "$expected_revenuecat_key_prefix"
expect_value "ACCOUNTAV_API_BASE_URL" "$(setting_value ACCOUNTAV_API_BASE_URL)" "$expected_api_base_url"
expect_value "SERIESAV_API_BASE_URL" "$(setting_value SERIESAV_API_BASE_URL)" "$expected_series_api_base_url"

revenuecat_public_api_key="$(setting_value SERIESAV_REVENUECAT_PUBLIC_API_KEY)"
if [[ "$revenuecat_public_api_key" == sk_* ]]; then
  printf 'Mismatch: SERIESAV_REVENUECAT_PUBLIC_API_KEY must not be a RevenueCat secret key.\n' >&2
  failures=$((failures + 1))
fi

if [ -z "$(setting_value SERIESAV_REVENUECAT_OFFERING_ID)" ] || [ "$(setting_value SERIESAV_REVENUECAT_OFFERING_ID)" = '$(inherited)' ]; then
  printf 'Mismatch: SERIESAV_REVENUECAT_OFFERING_ID is not resolved.\n' >&2
  failures=$((failures + 1))
fi

if [ -z "$(setting_value SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID)" ] || [ "$(setting_value SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID)" = '$(inherited)' ]; then
  printf 'Mismatch: SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID is not resolved.\n' >&2
  failures=$((failures + 1))
fi

management_url="$(setting_value ACCOUNTAV_MANAGEMENT_URL)"
if [[ "$management_url" != *"$expected_management_host"* ]]; then
  printf 'Mismatch: ACCOUNTAV_MANAGEMENT_URL must point at %s. Actual: %s\n' "$expected_management_host" "${management_url:-<empty>}" >&2
  failures=$((failures + 1))
fi

development_team="$(setting_value DEVELOPMENT_TEAM)"
if [ -z "$development_team" ] || [ "$development_team" = '$(inherited)' ]; then
  printf 'Mismatch: DEVELOPMENT_TEAM is not resolved. Actual: %s\n' "${development_team:-<empty>}" >&2
  failures=$((failures + 1))
fi

if [ "$(setting_value CODE_SIGN_ENTITLEMENTS)" != "SeriesAV/App/SeriesAV.entitlements" ]; then
  printf 'Mismatch: CODE_SIGN_ENTITLEMENTS is not SeriesAV/App/SeriesAV.entitlements.\n' >&2
  failures=$((failures + 1))
fi

if ! plutil -extract keychain-access-groups raw "$repo_root/apps/ios/SeriesAV/App/SeriesAV.entitlements" >/dev/null 2>&1; then
  printf 'Mismatch: SeriesAV.entitlements must include keychain-access-groups for Clerk native auth.\n' >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

printf 'Series AV iOS %s runtime config preflight passed.\n' "$profile"
