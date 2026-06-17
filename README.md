# Series AV

Open-source iOS app for Series AV.

This repository contains the iOS client app, local watch-list and progress flows, Account AV UI, backend-aware access handling, and TV metadata integration used by the product.

Before validating signed account, backend access, library sync, catalog,
or deletion workflows, read [AGENTS.md](AGENTS.md). Those workflows are governed
by private AVALSYS runbooks and must not be replaced with an invented local
backend flow.

## License

This repository is released under the MIT license. See [LICENSE](LICENSE).

## Repository Shape

```text
apps/
  ios/      SwiftUI iOS app
docs/
  ios-animation-performance.md
  install-ios.md
```

## What Is Included

- local-first series discovery and library flows
- watch progress and on-device settings
- Account AV UI surfaces
- native SwiftUI iOS app structure
- public TV metadata integration via TVMaze
- backend-backed access and app-data sync through private Account AV infrastructure

## Docs

- [iOS installation guide](docs/install-ios.md)
- [iOS animation and media performance guide](docs/ios-animation-performance.md)
- [Release checklist](docs/release-checklist.md)

## Third-Party Data Sources

- TV metadata currently comes from `TVmaze`.
- TVmaze's API licensing requires attribution. The app now exposes a visible attribution path in `Settings`, and the repo/docs should continue to keep that dependency explicit.
- TV/movie posters from approved catalog providers may be used as
  title-reference artwork in normal app UI by default; Series AV does not
  require manual poster approval one title at a time.
- Fallback artwork is used when a poster is missing, a source/policy flag blocks
  it, or screenshot/release mode requires fallback.
- Company/platform/provider logos, availability badges, deep links, trailers,
  and embedded provider pages are not covered by poster permission and require
  separate documented rights/terms evidence.
- Signed-in account, entitlement, and deletion behavior are separate from TV catalog data and remain tied to the private Account AV backend.

## Account Deletion Support

- Public deletion support URL: `https://series-av.avalsys.com/delete-account`
- Local-only users can remove on-device data from inside the app or by deleting the app.
- If an Account AV was used, the public deletion page documents the out-of-app request path and the provider-subscription caveats.

## Current Structure Notes

- All active app code lives under `apps/ios`.
- There is no separate public backend in this repository.
- Backend-backed features used by Series AV come from private Account AV infrastructure.
- When `ACCOUNTAV_API_BASE_URL` is configured, backend capabilities are authoritative for signed-in access.
- The V1 rebuild sync resource is `seriesLibrary` at `/v1/apps/seriesav/data/seriesLibrary`.

## Local Setup

1. Install dependencies:
   `bun install`
2. Create the local Infisical bootstrap at `.infisical/bootstrap.env`.
3. Generate the local iOS config:
   `bun run ios:config`
4. Build the iOS app:
   `bun run ios`

Account sign-in uses the configured Account AV provider. `ACCOUNTAV_PUBLISHABLE_KEY` is required for generated native iOS config.

If both the Account AV publishable key and `ACCOUNTAV_API_BASE_URL` are configured, the app can:

- hydrate signed-in access from `GET /v1/me/access`
- sync `seriesLibrary` through `/v1/apps/seriesav/data/seriesLibrary`
- use backend-backed Series AV catalog routes when those V1 routes are wired
- reflect guest, signed-in Free, and Pro account states in the iOS profile
- sell, restore, and manage the Pro entitlement through the Tune AV-style paywall and Account AV access refresh flow

## Local Secrets

Do not commit local config, secrets, signing files, provisioning profiles, or build artifacts. Use the root `.env.schema` as the canonical env contract and keep `.infisical/bootstrap.env` local-only.

The local config generator resolves the local Infisical bootstrap first and then reads values through Varlock.

## Commands

```bash
bun install
bun run ios:config
bun run ios
bun run typecheck
```

Current local gate:

- `bun run config:hygiene` checks that tracked public config does not expose private values.
- `bun run typecheck` generates local iOS config and builds the native iOS app for the simulator with code signing disabled.

Dependency maintenance:

```bash
bun run ncu
```

For simulator or physical iPhone installs, follow [docs/install-ios.md](docs/install-ios.md).

## Open product work

1. Finish TestFlight/App Store purchase, restore, webhook, and review
   screenshot validation for `seriesav_pro_monthly`.
2. Keep the shared RevenueCat project intact. Moments AV and Animate AV
   offerings may exist beside Series AV; Series AV readiness depends on
   offering `default` containing `$rc_monthly -> seriesav_pro_monthly`.
3. Finish production QA for backend-backed catalog routes where V1 needs
   account-aware data: Search/resolve, Detail, and compact episode guide.
4. Keep the reserved Avi limits documented, but do not expose Avi action copy or
   UI until Series AV has real Avi-assisted flows.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
