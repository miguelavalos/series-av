# Private Config And Infisical

This repository is public and open source. Anything committed here can become public, so production login, Pro, backend, signing, and account-management config must never be hardcoded in tracked files.

## Rules

1. Do not commit `apps/ios/Config/Local.xcconfig`.
2. Do not commit `.env`, `.env.*`, `.infisical/bootstrap.env`, signing files, provisioning profiles, or generated native build output.
3. Do not commit real account-provider keys, backend tokens, subscription sync tokens, or private service credentials.
4. Do not add production backend URLs as fallback constants in source or scripts. Production values must come from Infisical.
5. Keep public examples generic, for example `https://api.example.com` and `pk_test_your_publishable_key_here`.
6. Keep RevenueCat public SDK keys in generated local config only. They must use the `appl_` prefix and must never be RevenueCat secret keys.

## Generate Config

Local development:

```bash
bun install
bun run ios:config
```

Production/App Store preparation:

```bash
bun run ios:config:production
```

The production command must fail if Infisical does not provide required values.
Required Series AV Pro values are:

- `SERIESAV_REVENUECAT_PUBLIC_API_KEY`
- `SERIESAV_REVENUECAT_OFFERING_ID`
- `SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID`

## Before Pushing

Run this from the repository root:

```bash
PROD_API_HOST="${PROD_API_HOST:?set production API host}"
escaped_host="$(printf '%s' "$PROD_API_HOST" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
git ls-files -z -- ':!:docs/private-config-and-infisical.md' | xargs -0 rg -n "pk_live|sk_live|CLERK_SECRET_KEY=|ACCOUNTAV_SUBSCRIPTION_SYNC_TOKEN=|$escaped_host" || true
```

If this finds a real production value in a tracked file, remove it before pushing. If a real secret was already pushed, rotate it in the provider and clean the Git history.
