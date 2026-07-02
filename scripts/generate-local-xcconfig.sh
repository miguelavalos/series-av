#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-local}"
output_mode="${2:-write}"

case "$profile" in
  local)
    bundle_identifier="com.avalsys.seriesav.dev"
    ;;
  preview)
    bundle_identifier="com.avalsys.seriesav.dev"
    ;;
  production)
    bundle_identifier="com.avalsys.seriesav"
    ;;
  *)
    echo "Unsupported profile: $profile" >&2
    exit 1
    ;;
esac

eval "$("$repo_root/scripts/resolve-infisical-bootstrap-env.sh" "$profile")"

varlock_bin="$repo_root/node_modules/.bin/varlock"

if [ ! -x "$varlock_bin" ]; then
  echo "varlock CLI is required. Run 'pnpm install' in $repo_root." >&2
  exit 1
fi

printenv_value() {
  local key="$1"
  "$varlock_bin" printenv --path "$repo_root/" "$key" 2>/dev/null || true
}

xcodebuild_url_value() {
  local value="$1"
  printf '%s' "$value" | sed 's#//#/$()/#g'
}

account_publishable_key="$(printenv_value ACCOUNTAV_PUBLISHABLE_KEY)"
account_keychain_service="$(printenv_value ACCOUNTAV_KEYCHAIN_SERVICE)"
account_keychain_access_group="$(printenv_value ACCOUNTAV_KEYCHAIN_ACCESS_GROUP)"
avaccount_api_base_url="$(printenv_value ACCOUNTAV_API_BASE_URL)"
account_delete_account_url="$(printenv_value ACCOUNTAV_DELETE_ACCOUNT_URL)"
seriesav_api_base_url="$(printenv_value SERIESAV_API_BASE_URL)"
seriesav_convex_url="$(printenv_value SERIESAV_CONVEX_URL)"
seriesav_delete_account_url="$(printenv_value SERIESAV_DELETE_ACCOUNT_URL)"
account_management_url="$(printenv_value ACCOUNTAV_MANAGEMENT_URL)"
revenuecat_public_api_key="$(printenv_value SERIESAV_REVENUECAT_PUBLIC_API_KEY)"
revenuecat_offering_id="$(printenv_value SERIESAV_REVENUECAT_OFFERING_ID)"
revenuecat_monthly_package_id="$(printenv_value SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID)"
terms_url="$(printenv_value SERIESAV_TERMS_URL)"
privacy_url="$(printenv_value SERIESAV_PRIVACY_URL)"
seriesav_web_base_url="$(printenv_value SERIESAV_WEB_BASE_URL)"
support_email="$(printenv_value SERIESAV_SUPPORT_EMAIL)"
open_source_url="$(printenv_value SERIESAV_OPEN_SOURCE_URL)"
development_team="$(printenv_value AVALSYS_APPLE_DEVELOPMENT_TEAM)"

if [ -z "$seriesav_web_base_url" ]; then
  case "$profile" in
    production)
      seriesav_web_base_url="https://app.series-av.avalsys.com"
      ;;
    *)
      seriesav_web_base_url="https://app.series-av-preview.avalsys.com"
      ;;
  esac
fi

if [ -z "$development_team" ]; then
  development_team="\$(inherited)"
fi

if [ "$development_team" = "346677S99H" ]; then
  echo "Warning: replacing stale non-Avalsys Apple team 346677S99H with 935PM55U6R." >&2
  development_team="935PM55U6R"
fi

if [ -z "$account_keychain_access_group" ]; then
  account_keychain_access_group="935PM55U6R.$bundle_identifier"
fi

required_values=(
  account_publishable_key
  avaccount_api_base_url
  seriesav_api_base_url
  seriesav_convex_url
  terms_url
  privacy_url
  account_management_url
  revenuecat_public_api_key
  revenuecat_offering_id
  revenuecat_monthly_package_id
  support_email
)

for value_name in "${required_values[@]}"; do
  if [ -z "${!value_name:-}" ]; then
    echo "Missing required value from Infisical: $value_name" >&2
    exit 1
  fi
done

case "$revenuecat_public_api_key" in
  appl_*) ;;
  *)
    echo "SERIESAV_REVENUECAT_PUBLIC_API_KEY must be a RevenueCat public app key with appl_ prefix." >&2
    exit 1
    ;;
esac

case "$revenuecat_public_api_key" in
  sk_*)
    echo "SERIESAV_REVENUECAT_PUBLIC_API_KEY must not be a RevenueCat secret key." >&2
    exit 1
    ;;
esac

case "$seriesav_convex_url" in
  https://*.convex.cloud) ;;
  *)
    echo "SERIESAV_CONVEX_URL must be a Convex cloud URL." >&2
    exit 1
    ;;
esac

for url_name in account_delete_account_url seriesav_delete_account_url; do
  url_value="${!url_name:-}"
  if [ -n "$url_value" ]; then
    case "$url_value" in
      https://*) ;;
      *)
        echo "$url_name must use HTTPS." >&2
        exit 1
        ;;
    esac
  fi
done

rendered_config="$(cat <<EOF
SERIESAV_BUNDLE_IDENTIFIER = $bundle_identifier
AVALSYS_APPLE_DEVELOPMENT_TEAM = $development_team
ACCOUNTAV_PUBLISHABLE_KEY = $account_publishable_key
ACCOUNTAV_KEYCHAIN_SERVICE = $account_keychain_service
ACCOUNTAV_KEYCHAIN_ACCESS_GROUP = $account_keychain_access_group
ACCOUNTAV_API_BASE_URL = $(xcodebuild_url_value "${avaccount_api_base_url:-}")
ACCOUNTAV_DELETE_ACCOUNT_URL = $(xcodebuild_url_value "${account_delete_account_url:-}")
SERIESAV_API_BASE_URL = $(xcodebuild_url_value "${seriesav_api_base_url:-}")
SERIESAV_CONVEX_URL = $(xcodebuild_url_value "${seriesav_convex_url:-}")
SERIESAV_DELETE_ACCOUNT_URL = $(xcodebuild_url_value "${seriesav_delete_account_url:-}")
SERIESAV_REVENUECAT_PUBLIC_API_KEY = $revenuecat_public_api_key
SERIESAV_REVENUECAT_OFFERING_ID = $revenuecat_offering_id
SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID = $revenuecat_monthly_package_id
SERIESAV_TERMS_URL = $(xcodebuild_url_value "${terms_url:-}")
SERIESAV_PRIVACY_URL = $(xcodebuild_url_value "${privacy_url:-}")
SERIESAV_WEB_BASE_URL = $(xcodebuild_url_value "${seriesav_web_base_url:-}")
ACCOUNTAV_MANAGEMENT_URL = $(xcodebuild_url_value "${account_management_url:-}")
SERIESAV_SUPPORT_EMAIL = ${support_email:-}
SERIESAV_OPEN_SOURCE_URL = $(xcodebuild_url_value "${open_source_url:-}")
SERIESAV_DEBUG_FORCE_PRO_MODE = NO
SERIESAV_DEBUG_SEED_SOCIAL_PREVIEW = NO
SERIESAV_DEBUG_PREVIEW_DISPLAY_NAME =
SERIESAV_DEBUG_PREVIEW_EMAIL =
EOF
)"

target_file="$repo_root/apps/ios/Config/Local.xcconfig"

case "$output_mode" in
  write)
    umask 077
    printf '%s\n' "$rendered_config" > "$target_file"
    echo "Wrote $target_file for profile '$profile'."
    ;;
  stdout)
    printf '%s\n' "$rendered_config"
    ;;
  *)
    echo "Unsupported output mode: $output_mode" >&2
    exit 1
    ;;
esac
