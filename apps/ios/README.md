# Series AV iOS Rebuild

Status: V1 rebuild scaffold.

The previous iOS app has been moved to:

```text
apps/ios_old
```

Use `apps/ios_old` as reference material only. New Series AV iOS work should be
built here from the shared Apps AV Apple product foundation, using the shared
Account AV and Apps AV packages before reintroducing product-specific screens,
models, and workflows.

Current scaffold:

- XcodeGen project and compile-only iOS app target.
- V1 local library models with a single progress cursor per series.
- Local store behavior for reversible progress updates and Home priority.
- Guest, signed-in Free, and Pro access models aligned with Account AV `/v1/me/access`.
- Series AV entitlement service that selects the `seriesav` app entry and uses
  the Apps AV user id as the account authority.
- Shared Account AV service/controller foundation for provider session restore,
  Apps AV account identity resolution, access refresh, and sign-out.
- Shared Account AV onboarding/sign-in shell wired through the Series AV app
  bootstrap, with the current library screen behind the account gate.
- Common language/theme controllers and the shared product-app localization set.
- Visible Account/Profile/Settings shell using the shared Apps AV settings
  surfaces, with app language first, appearance second, local tracking context,
  help/legal links, session state, and account safety links.
- Pro cloud-sync client contract for `/v1/apps/seriesav/data/seriesLibrary`.
- RevenueCat-backed Series AV Pro purchase/restore boundary and custom paywall
  shell, guarded by public xcconfig/Info.plist config and backend access
  reconciliation.
- Unit-test build coverage for library identity, cursor updates, app-data sync
  envelopes, access entitlement resolution, account session hydration, and Pro
  purchase reconciliation.

Not implemented yet:

- final Series AV UI redesign;
- private RevenueCat/App Store product configuration and signed purchase smoke;
- advanced account-management flows beyond shared links;
- Convex realtime projection;
- catalog search/enrichment UI;
- social features.

The private rebuild decision record is:

```text
private/avalsys-suite/docs/series-av/redesign-and-rebuild-plan.md
```
