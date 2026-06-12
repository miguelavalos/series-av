# Series AV

Open-source iOS app for Series AV.

This repository contains the iOS client app, local watch-list and progress flows, Account AV UI, backend-aware access handling, and TV metadata integration used by the product.

Before validating signed account, backend access, library sync, social/catalog,
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
- backend-backed access, app-data sync, and Series AV catalog/social integration through private Account AV infrastructure

## Docs

- [iOS installation guide](docs/install-ios.md)
- [iOS animation and media performance guide](docs/ios-animation-performance.md)

## Third-Party Data Sources

- TV metadata currently comes from `TVmaze`.
- TVmaze's API licensing requires attribution. The app now exposes a visible attribution path in `Settings`, and the repo/docs should continue to keep that dependency explicit.
- TV/movie posters may be used as title-reference artwork when provider terms,
  attribution, and release evidence support that use.
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
- Pro social surfaces and shared library sync are now wired in the public client.

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
- sync `library` through `/v1/apps/seriesav/data/library`
- use backend-backed Series AV catalog and Pro social routes
- reflect `local`, `connected`, and `pro` account states in the iOS profile without selling or managing subscriptions inside the app

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

1. Run full end-to-end signed-in behavior checks against the real Account AV provider and Account AV backend environments.
2. Run the private signed-in free/pro smoke prompt gates with a real Account AV session token in preview and production.
3. Collect real catalog mismatch examples that still fail after the current TheTVDB matching hardening.
4. Validate the iOS signed-in simulator flow against preview before promoting future backend changes to production.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
