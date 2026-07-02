# Series AV iOS Installation

This guide covers local iOS development for the SwiftUI app.

## Prerequisites

1. Xcode installed from the Mac App Store or Apple Developer.
2. Vite+/pnpm 1.3.13 or later available locally.
3. A local `.infisical/bootstrap.env`.

## Setup

```bash
pnpm install
vp run ios:config
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

Accepted V1 access limits are compiled into the iOS access layer. Avi is visible
in V1 as contextual tracking guidance on Home and the Avi tab; it is not a
separate metered action surface in the iOS client.

- Guest: 25 active library series.
- Signed-in Free: 75 active library series.
- Pro: 1000 active library series.

## Native iOS Build

Generate the Swift iOS local config from Infisical before building:

```bash
vp run ios:config
vp run ios:preflight
```

For preview Account AV validation against Cloudflare preview:

```bash
vp run ios:config:preview
vp run ios:preflight:preview
```

For production/App Store preparation:

```bash
vp run ios:config:production
vp run ios:preflight:production
```

Series AV Pro is a paid/subscription V1. Before TestFlight or App Store
submission, the private suite readiness checks must also pass for preview and
production:

```bash
vp run series-av:subscription:readiness:preview
vp run series-av:subscription:readiness:production
```

Those checks validate the Infisical-backed RevenueCat client values and the
Apps AV product map entry for `seriesav_pro_monthly -> seriesav` without
printing secrets.

`apps/ios/Config/Local.xcconfig` is gitignored. Do not commit it or copy production values into versioned files.

## Native Tests

Series AV includes native unit and UI smoke tests. Use a signed or unsigned
Debug simulator test build for local regression checks; keep DerivedData
repo-local and purpose-named:

```bash
xcodebuild test \
  -project apps/ios/SeriesAV.xcodeproj \
  -scheme SeriesAV \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=<simulator name>' \
  -derivedDataPath .DerivedData-seriesav-ui-tests
```

The UI test target uses `SERIESAV_UI_TESTS` launch-environment hooks for
deterministic guest/free/pro, populated-library, paywall, and guided-progress
states. These hooks must stay test-only and must not be used as evidence for
real signed Account AV, RevenueCat purchase, or backend provider validation.

## Switching Runtime Profiles

Always regenerate and preflight the native config after switching between
local, preview, and production. Do this before opening Xcode, running the
simulator, archiving, or testing Clerk/Account AV sign-in.

## Dev Auth Smoke

Use this sequence when testing native Account AV sign-in from the simulator:

```bash
vp run ios:config
vp run ios:preflight
```

Then run the app from Xcode or a signed simulator build. The dev preflight must
resolve:

- bundle identifier: `com.avalsys.seriesav.dev`
- Clerk key prefix: `pk_test_`
- Account AV API: `http://127.0.0.1:8788`
- Series AV API: `http://127.0.0.1:8791`
- Account AV management URL host: `account-av-preview.avalsys.com`
- RevenueCat public SDK key prefix: `appl_`
- non-empty RevenueCat offering and monthly package ids
- a concrete Apple development team
- `SeriesAV/App/SeriesAV.entitlements` with Keychain access groups

For preview Cloudflare validation, use `vp run ios:config:preview` and
`vp run ios:preflight:preview`. The preview preflight must resolve the same
development bundle id and test Clerk key, but the Account AV API must be
`https://api-account-av-preview.avalsys.com` and the Series AV API must be
`https://api-series-av-preview.avalsys.com`.

Do not use the unsigned compile-only build for Google or Apple login. Clerk
native auth stores its client and device token in Keychain; unsigned simulator
builds can produce Keychain `-34018` errors and then fail OAuth with
`signed_out`.

To build the native project locally:

```bash
vp run ios
```

`vp run ios` and `vp run typecheck` compile the simulator app with
`CODE_SIGNING_ALLOWED=NO` so CI and local compile checks do not depend on a
developer certificate. Do not use that unsigned build to validate Google or
Apple sign-in: Account AV native auth requires a signed app with the Keychain
and Apple Sign In entitlements active. For auth smoke testing, run from Xcode
with the generated development team selected or use the signed iOS simulator
build/run workflow from Codex/Xcode.

## Local Build Cache Cleanup

Xcode `DerivedData` can grow by several gigabytes per build/test profile,
especially when agents repeat simulator, device, and archive validation. For
manual `xcodebuild` commands, keep build output repo-local and purpose-named:

```bash
xcodebuild ... -derivedDataPath .DerivedData-<task-name>
```

Measure local native caches before closing the task:

```bash
find . -type d \( -name '.DerivedData*' -o -name '.derived-data*' -o -name 'DerivedData' \) -prune -print0 | xargs -0 du -sh
```

Clean only when no active build is using those directories:

```bash
find . -type d \( -name '.DerivedData*' -o -name '.derived-data*' -o -name 'DerivedData' \) -prune -print0 | xargs -0 rm -rf
```

## Production Runtime Check

Before archiving or uploading a production build:

```bash
vp run ios:config:production
vp run ios:preflight:production
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

## Share Invite Link QA

Series AV private share invites use HTTPS URLs shaped like:

```text
https://app.series-av.avalsys.com/i/r/<token>?lang=es
```

Production TestFlight builds must be tested with production invite links. A
preview-domain invite token is not valid against the production API used by a
Release/TestFlight build.

The app supports two native entry paths:

- Universal Links for `https://app.series-av.avalsys.com/i/r/*` and
  `https://app.series-av-preview.avalsys.com/i/r/*`.
- Custom-scheme fallback links shaped like
  `com.avalsys.seriesav://i/r/<token>`.

If WhatsApp or Safari opens the browser instead of the installed TestFlight app,
first confirm the web preview shows the invite and use the visible **Open in
Series AV** / **Abrir en Series AV** fallback button. iOS caches Universal Link
association state per app install and domain; after AASA or domain fixes,
delete and reinstall the TestFlight build to force a fresh association fetch
before treating direct HTTPS handoff as an app-code failure.
