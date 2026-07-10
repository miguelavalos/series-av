# Series AV iOS

Status: shipping V1 maintenance and native UI quality improvements. The current
public App Store baseline is documented in `../../docs/release-checklist.md`.

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
- Series access limits mirror `shared/contracts/access-policy.json`, including
  `activeLibrarySeries` and `aviActionsPerDay`.
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
- Pro cloud-sync client and runtime coordinator for
  `/v1/apps/seriesav/data/seriesLibrary`, enabled only when Apps AV access
  exposes `canUseCloudSync`.
- RevenueCat-backed Series AV Pro purchase/restore boundary and custom paywall
  shell, guarded by public xcconfig/Info.plist config and backend access
  reconciliation.
- Runtime config preflight for Account AV, Convex URL, RevenueCat, keychain
  access group, support/legal URLs, and release archive checks.
- Home, Library, Search, and Avi product tabs using the shared Apps AV shell.
- Adaptive iPhone tab and iPad sidebar layouts, with Dynamic Type-aware Home,
  Library, Search, detail, Profile, and account-deletion screens. The implemented
  UI baseline and remaining review order are documented in
  `../../docs/ios-ui-quality-review.md`.
- Search shows popular collections, genre/anime filters, backend-enriched
  signed-in results, and editorial fallback rows. Any catalog or fallback row
  that has an approved provider poster should render it; text fallback artwork
  is only for missing/blocked posters. Search sections should expose a compact
  result count or update state so default collections and typed searches are
  understandable without extra explanatory UI. Default Search collections must
  show local curated results immediately while backend enrichment updates
  posters and identifiers in place. Adding a series from Search or Home
  discovery should immediately open progress adjustment, and exact local/catalog
  matches should be shown once as the local tracked row. Search cards use
  normalized catalog status, latest known season, and episode count as compact
  supplementary metadata when providers return those fields.
- Home discovery exposes explicit loading and retry states, preserves the latest
  successful in-session result during refresh failures, and reserves its bottom
  safe-area bar only for a pending undo action.
- Episode tracking uses one reversible progress cursor, compact season/episode
  selection, known episode guides when available, and generic large-range
  episode navigation when no guide is available. The progress editor must make
  the resulting state explicit: the selected cursor is the last watched point,
  all previous episodes become watched, following episodes become pending, the
  next episode remains visible, and the primary action should include the exact
  target cursor.
- Unit-test build coverage for library identity, cursor updates, safe initial
  cloud pull/merge behavior, app-data sync envelopes, access entitlement
  resolution, account session hydration, account-deletion error context, and Pro
  purchase reconciliation. The focused unit suite passed 120 tests on
  2026-07-10.

Release/prod runtime config check:

```bash
scripts/verify-ios-runtime-config.sh production
```

Account-gated onboarding tests should model the real restore contract: active
provider session, non-empty provider token, and internal Apps AV user resolution
before asserting signed-in UI state.

After the 2026-06-21 App Store submission of iOS `1.0 (11)`, still pending:

- App Review monitoring for submission
  `914c99f2-95c6-4b0d-a651-d15433efe639`;
- signed purchase/restore smoke through the submitted RevenueCat/App Store
  subscription configuration after approval or a safe store test path;
- signed Pro cloud-sync smoke against the submitted Apps AV environment;
- advanced account-management flows beyond shared links;
- Convex realtime projection;
- full catalog/enrichment polish beyond the current V1 search and fallback UI;

The private rebuild decision record is:

```text
private/avalsys-suite/docs/series-av/redesign-and-rebuild-plan.md
```
