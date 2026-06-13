# Series AV iOS Installation

This guide covers local iOS development for the SwiftUI app.

## Prerequisites

1. Xcode installed from the Mac App Store or Apple Developer.
2. Bun 1.3.13 or later available locally.
3. A local `.infisical/bootstrap.env`.

## Setup

```bash
bun install
bun run ios:config
```

`ACCOUNTAV_PUBLISHABLE_KEY` is required for generated native iOS config.
When `ACCOUNTAV_API_BASE_URL` is also configured, signed-in builds can refresh
the account-backed access state used to show local, connected, or Pro status in
the app.
Series AV Pro also requires `SERIESAV_REVENUECAT_PUBLIC_API_KEY`,
`SERIESAV_REVENUECAT_OFFERING_ID`, and
`SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID` in Infisical before generating native
config. The RevenueCat public key must use the Apple public SDK `appl_` prefix;
never put a RevenueCat secret key in native config.
V1 uses the same guest/free local-only and Pro paywall/subscription pattern as
Tune AV. Cloud sync is Pro-only.

Accepted V1 access limits are compiled into the iOS access layer. The Avi daily
limits are a reserved entitlement contract for later Avi-assisted Series AV
flows; the current V1 iOS surface does not expose standalone Avi actions yet.

- Guest: 25 active library series and 5 Avi actions/day.
- Signed-in Free: 75 active library series and 15 Avi actions/day.
- Pro: 1000 active library series and practical fair-use Avi.

## Native iOS Build

Generate the Swift iOS local config from Infisical before building:

```bash
bun run ios:config
bun run ios:preflight
```

For production/App Store preparation:

```bash
bun run ios:config:production
bun run ios:preflight:production
```

Series AV Pro is a paid/subscription V1. Before TestFlight or App Store
submission, the private suite readiness checks must also pass for preview and
production:

```bash
bun run series-av:subscription:readiness:preview
bun run series-av:subscription:readiness:production
```

Those checks validate the Infisical-backed RevenueCat client values and the
Apps AV product map entry for `seriesav_pro_monthly -> seriesav` without
printing secrets.

`apps/ios/Config/Local.xcconfig` is gitignored. Do not commit it or copy production values into versioned files.

## Switching Dev And Production

Always regenerate and preflight the native config after switching between dev and production. Do this before opening Xcode, running the simulator, archiving, or testing Clerk/Account AV sign-in.

## Dev Auth Smoke

Use this sequence when testing native Account AV sign-in from the simulator:

```bash
bun run ios:config
bun run ios:preflight
```

Then run the app from Xcode or a signed simulator build. The dev preflight must
resolve:

- bundle identifier: `com.avalsys.seriesav.dev`
- Clerk key prefix: `pk_test_`
- Account AV API: `http://127.0.0.1:8788`
- Account AV management URL host: `account-av-preview.avalsys.com`
- RevenueCat public SDK key prefix: `appl_`
- non-empty RevenueCat offering and monthly package ids
- a concrete Apple development team
- `SeriesAV/App/SeriesAV.entitlements` with Keychain access groups

Do not use the unsigned compile-only build for Google or Apple login. Clerk
native auth stores its client and device token in Keychain; unsigned simulator
builds can produce Keychain `-34018` errors and then fail OAuth with
`signed_out`.

To build the native project locally:

```bash
bun run ios
```

`bun run ios` and `bun run typecheck` compile the simulator app with
`CODE_SIGNING_ALLOWED=NO` so CI and local compile checks do not depend on a
developer certificate. Do not use that unsigned build to validate Google or
Apple sign-in: Account AV native auth requires a signed app with the Keychain
and Apple Sign In entitlements active. For auth smoke testing, run from Xcode
with the generated development team selected or use the signed iOS simulator
build/run workflow from Codex/Xcode.

## Production Runtime Check

Before archiving or uploading a production build:

```bash
bun run ios:config:production
bun run ios:preflight:production
```

The production preflight must resolve:

- bundle identifier: `com.avalsys.seriesav`
- Clerk key prefix: `pk_live_`
- Account AV API: `https://api-account-av.avalsys.com`
- Account AV management URL host: `account-av.avalsys.com`
- RevenueCat public SDK key prefix: `appl_`
- non-empty RevenueCat offering and monthly package ids

If any value is different, regenerate config from the right profile before
building. Do not hand-edit `Local.xcconfig`.
