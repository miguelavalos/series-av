# Series AV

Open-source iOS and web clients for Series AV.

This repository contains the iOS and web client apps, local watch-list and progress flows, Account AV UI, backend-aware access handling, and Series AV catalog integration used by the product.

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
  web/      TanStack Start web app
docs/
  ios-animation-performance.md
  install-ios.md
```

## What Is Included

- local-first series discovery and library flows
- watch progress and on-device settings
- Account AV UI surfaces
- native SwiftUI iOS app structure
- signed-in web app structure
- Series AV catalog, detail, episode-guide, artwork, and external-link integration
- backend-backed access and app-data sync through private Account AV infrastructure

## Docs

- [iOS installation guide](docs/install-ios.md)
- [iOS animation and media performance guide](docs/ios-animation-performance.md)
- [Release checklist](docs/release-checklist.md)

## Catalog And External Links

- Series metadata, artwork policy, episode guides, and enriched external links
  are read from the Series AV API.
- User-facing source shortcuts should stay familiar and product-oriented:
  IMDb, Wikipedia, and the user's chosen web search engine.
- Provider/source identifiers such as `thetvdb:*` may exist in API payloads and
  route IDs, but should not be promoted as primary user-facing source links.
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

- Active client app code lives under `apps/ios` and `apps/web`.
- There is no separate public backend in this repository.
- Backend-backed features used by Series AV come from private Account AV infrastructure.
- When `ACCOUNTAV_API_BASE_URL` is configured, backend capabilities are authoritative for signed-in access.
- The V1 rebuild sync resource is `seriesLibrary` at `/v1/apps/seriesav/data/seriesLibrary`.

## Local Setup

1. Install dependencies:
   `pnpm install`
2. Create the local Infisical bootstrap at `.infisical/bootstrap.env`.
3. Generate the local iOS config:
   `vp run ios:config`
4. Build the iOS app:
   `vp run ios`

Account sign-in uses the configured Account AV provider. `ACCOUNTAV_PUBLISHABLE_KEY` is required for generated native iOS config.

If both the Account AV publishable key and `ACCOUNTAV_API_BASE_URL` are configured, the app can:

- hydrate signed-in access from `GET /v1/me/access`
- sync `seriesLibrary` through `/v1/apps/seriesav/data/seriesLibrary`
- use backend-backed Series AV catalog, detail, episode-guide, and external-link routes
- reflect guest, signed-in Free, and Pro account states in the iOS profile
- sell, restore, and manage the Pro entitlement through the Tune AV-style paywall and Account AV access refresh flow

## Local Secrets

Do not commit local config, secrets, signing files, provisioning profiles, or build artifacts. Use the root `.env.schema` as the canonical env contract and keep `.infisical/bootstrap.env` local-only.

The local config generator resolves the local Infisical bootstrap first and then reads values through Varlock.

## Commands

```bash
pnpm install
vp run ios:config
vp run ios
vp run typecheck
```

Current local gate:

- `vp run config:hygiene` checks that tracked public config does not expose private values.
- `vp run typecheck` generates local iOS config and builds the native iOS app for the simulator with code signing disabled.

Dependency maintenance:

```bash
vp run ncu
```

For simulator or physical iPhone installs, follow [docs/install-ios.md](docs/install-ios.md).

## Open product work

1. Treat iOS/iPadOS version `1.0.2 (13)` as the current public App Store
   baseline for client compatibility work.
2. Continue purchase, restore, RevenueCat webhook, and Apps AV entitlement
   validation for
   `seriesav_pro_monthly`.
3. Keep the shared RevenueCat project intact. Moments AV and Animate AV
   offerings may exist beside Series AV; Series AV readiness depends on
   offering `default` containing `$rc_monthly -> seriesav_pro_monthly`.
4. Finish production QA for backend-backed catalog routes where V1 needs
   account-aware data: Search/resolve, Detail, and compact episode guide.
5. Keep the reserved Avi limits documented, but do not expose Avi action copy or
   UI until Series AV has real Avi-assisted flows.

## Contributing And Security

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
