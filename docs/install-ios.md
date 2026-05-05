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
```

For production/App Store preparation:

```bash
bun run ios:config:production
```

`apps/ios/Config/Local.xcconfig` is gitignored. Do not commit it or copy production values into versioned files.

To build the native project locally:

```bash
bun run ios
```
