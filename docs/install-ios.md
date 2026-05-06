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
This first iOS release does not sell subscriptions, restore purchases, or manage
subscription state from inside the app.

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

If any value is different, regenerate config from the right profile before
building. Do not hand-edit `Local.xcconfig`.
