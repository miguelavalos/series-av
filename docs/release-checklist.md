# Release Checklist

Use this checklist before uploading the first App Store build and before later production releases.

## Repository Hygiene

1. Run `bun install`.
2. Run:

   ```bash
   bun run config:hygiene
   ```

3. Confirm these files are not present in the public repo workspace:
   - `apps/ios/Config/Local.xcconfig`
   - `.env`
   - `.env.*`
   - `.infisical/bootstrap.env`
4. Confirm no signing files, provisioning profiles, private keys, exported certificates, or local build products are present.
5. Confirm public docs and tracked files do not expose Team IDs, private account names, provider secrets, smoke tokens, or private backend values.

## Build Verification

1. Generate local config outside git:

   ```bash
   bun run ios:config
   ```

2. Build for simulator:

   ```bash
   bun run typecheck
   ```

3. Build a signed simulator or device candidate from Xcode before validating Sign in with Apple. The `bun run typecheck` simulator artifact intentionally disables code signing and cannot be used to approve Apple auth.
4. Build a release candidate locally from Xcode before archiving for App Store Connect.
5. Before any TestFlight/App Store archive or upload, run the production
   simulator release gate:

   ```bash
   bun run ios:config:production
   bun run ios:release:simulator
   ```

   This gate validates public config hygiene, production runtime config,
   production Series API Search dependencies, focused native tests for Search
   loading and shell flows, a Release simulator build, and a screenshot evidence
   capture from the Release/prod Search screen. It does not replace signed
   device/TestFlight purchase, restore, Apple auth, or real Universal Link QA.
6. Confirm the shipping version and build number are correct for App Store Connect. `1.0 (1)` is acceptable only if this is the first uploaded build for version `1.0`; otherwise increment `CFBundleVersion`.

## Automated And Manual QA

The iOS project has native XCTest and UI test targets. Run the native suite
before manual release sign-off:

```bash
xcodebuild test \
  -project apps/ios/SeriesAV.xcodeproj \
  -scheme SeriesAV \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=<simulator name>' \
  -derivedDataPath .DerivedData-seriesav-ui-tests
```

The suite covers local library behavior, account/access policy, sync merge
behavior, follow-from-search smoke, populated-library smoke, guided progress
smoke, and guest/free/pro paywall/account smoke states. Manual QA still must
cover real signed sessions, App Store purchase dialogs, provider callbacks, and
device-specific Apple auth behavior.

### Guest

1. Launch app from clean install.
2. Dismiss onboarding and continue as guest.
3. Verify Home loads featured rows and continue-watching state without crash.
4. Search for at least one known show and open detail.
5. Follow a catalog result and confirm it appears in `Biblioteca`.
6. Open `Próximos` and verify next-up content renders.
7. Open `Perfil` and confirm privacy, terms, support, source code, search-engine preferences, and link-opening preferences are visible.

### Signed-In Free

1. Sign in with Apple from a signed simulator/device build, or explicitly record why simulator Apple auth had to be validated on physical device/TestFlight.
2. Sign in with Google from the simulator to confirm the web OAuth path still works.
3. Sign in with a real Account AV account in preview.
4. Confirm account state resolves as connected/free, not Pro.
5. Confirm Profile > Account safety > Delete Apps AV account opens the native deletion flow without a browser login.
6. Confirm backend access refresh succeeds.
7. Confirm Pro-only surfaces are not incorrectly exposed.
8. Confirm local library remains usable after sign-in and sign-out.

### Signed-In Pro

1. Sign in with Apple from a signed simulator/device build, or explicitly record why simulator Apple auth had to be validated on physical device/TestFlight.
2. Sign in with Google from the simulator to confirm the web OAuth path still works.
3. Sign in with a real Pro account in preview.
4. Confirm account state resolves as Pro.
5. Confirm Pro active-series limits are exposed correctly.
6. Confirm cloud library sync runs and status updates in profile when the submitted build enables Pro sync.
7. Confirm signed-in search/detail can resolve backend-backed catalog data where expected.
8. Confirm no visible shared-list, recommendation inbox, friends, public activity, or social-network surface is exposed in V1.
9. Confirm private share invites can be created by a Pro account and shared as
   `/i/r/<token>` links without exposing email, provider subject ids, public
   people search, contact lists, followers, or activity feeds.

### Production iOS QA Before TestFlight

App Store/TestFlight purchase, restore, and webhook evidence must still be
completed on an approved TestFlight/App Store build. Local
simulator QA can validate production config, signed Account AV session restore,
paywall offer loading, restore button visibility, and non-purchase UI behavior,
but it must not replace a real store purchase/restore validation.

Submission snapshot, 2026-06-21: iOS app version `1.0 (11)` was submitted to
App Review and is `Pendiente de revisión` in App Store Connect. The subscription
review screenshot and promotional image were attached before submission.

1. Generate production iOS config and run the app:

   ```bash
   bun run ios:config:production
   ```

2. Sign in with a safe production Account AV account and confirm Account AV
   access hydrates as signed-in Free or Pro according to its current backend
   entitlement.
3. Confirm Pro cloud sync uses `/v1/apps/seriesav/data/seriesLibrary` when the
   account has Pro access:
   follow a catalog result, change progress, archive/delete where applicable,
   relaunch, and verify sync status updates.
4. Confirm Search/resolve returns canonical backend `seriesId` values.
5. Confirm resolved series load the compact episode guide. Web must not expose
   free-form manual season/episode inputs; progress changes come from guided
   actions or selecting real backend episode-guide rows.
6. Run light mode, dark mode, Dynamic Type, five-locale, and long-string checks
   across Home, Library, Search, Detail, Profile, Account, Settings, Avi,
   guided progress actions, and Paywall.
7. Confirm a production private share invite opens safely from WhatsApp/Safari:
   direct Universal Link handoff should open the installed TestFlight app when
   iOS has refreshed the domain association; if it opens browser, the web page
   must render the invite and the **Open in Series AV** fallback must open the
   native app through `com.avalsys.seriesav://i/r/<token>`.
8. If direct Universal Link handoff fails after AASA/domain changes, delete and
   reinstall the TestFlight build before treating it as an app-code failure,
   because iOS caches association state per install/domain.
9. If a temporary internal grant is used for QA, revoke or allow it to expire
   after QA. It is smoke/QA evidence only and must not replace purchase/restore
   validation.

### Production Signed-In Smoke

Current evidence:

- preview Free and Pro auto smokes passed;
- production Free passed with a safe real Account AV session;
- production Pro passed with a safe real Account AV session using a temporary
  internal Series AV grant.

Additional local simulator evidence, 2026-06-17:

- production Release build restored an existing signed Account AV session and
  displayed signed-in account state in the Account screen;
- production RevenueCat offer loading returned `seriesav_pro_monthly` with
  display price `$2.99`;
- dark mode and Dynamic Type checks passed visually across Home, Search,
  Library, Account, Settings, Onboarding/Auth, Avi, guided progress actions, and
  Paywall;
- no purchase was initiated.

1. Re-run preview smoke against a real signed-in Account AV session token before
   final submission:

   ```bash
   bun run verify:cloudflare:signed-in:preview:prompt -- --mode signedInFree
   bun run verify:cloudflare:signed-in:preview:prompt -- --mode signedInPro
   ```

2. Re-run production smoke against a safe real account before final submission:

   ```bash
   bun run verify:cloudflare:signed-in:production:prompt -- --mode signedInFree --skip-preflight
   bun run verify:cloudflare:signed-in:production:prompt -- --mode signedInPro --skip-preflight
   ```

3. Confirm `signedInFree` and `signedInPro` capability boundaries still match the shipped product copy.

## App Store And Account Compliance

1. Confirm App Store Connect privacy policy URL points to `https://series-av.avalsys.com/privacy`.
2. Confirm the delete-account support URL is `https://series-av.avalsys.com/delete-account`.
3. Confirm review notes explain the shared Apps AV account-deletion flow, linked-app blockers, and provider-managed subscription caveat.
4. Confirm the build exposes the native in-app route at Profile > Account safety > Delete Apps AV account.
5. Confirm store metadata does not promise cloud sync, standalone Avi action
   limits, social features, or purchase flows that are not active in the
   submitted build.
6. Confirm visible TV/movie posters come from approved catalog providers or
   Series AV-owned/generated artwork, and that screenshot/release mode is using
   the intended artwork policy.
7. Confirm visible series source shortcuts use familiar user-facing destinations
   such as IMDb, Wikipedia, and the selected web search engine rather than
   provider-internal identifiers.
8. Confirm no company/platform/provider logos, availability badges, deep links,
   trailers, or embedded provider pages are visible without separate
   documented rights/terms evidence.

## Account AV And Backend

1. Confirm `ACCOUNTAV_PUBLISHABLE_KEY` is valid for the shipping environment.
2. Confirm `ACCOUNTAV_API_BASE_URL` points at the intended environment.
3. Confirm `GET /v1/me/access` works for signed-in builds.
4. Confirm `GET /v1/me` returns Account AV deletion eligibility, or record that the native app blocks deletion conservatively until eligibility is available.
5. Confirm preview and production support, privacy, terms, and open-source URLs are live.

## Pro And Entitlements

The first iOS release ships with the Tune AV-style Pro paywall, RevenueCat
purchase/restore handling, and App Store subscription management.

Current external setup snapshot, 2026-06-21:

- App Store Connect has subscription group `Series AV Pro` and monthly product
  `seriesav_pro_monthly` configured at USD 2.99 base price, all current
  countries and regions, and future country/region availability enabled.
- App Store Connect reports `Series AV Pro Monthly` as `Lista para enviar`.
  Product images, product localizations, group localizations, price, and review
  notes are complete. The subscription was attached to the submitted iOS
  `1.0 (11)` app version.
- RevenueCat has product `seriesav_pro_monthly` attached to entitlement `pro`
  and included in offering `default`, package `$rc_monthly`.
- Production `ios:preflight` and iOS simulator build passed after the setup.
- Local production simulator offer loading on 2026-06-17 confirmed
  `seriesav_pro_monthly` loads through RevenueCat and displays `$2.99`.
- The RevenueCat project is shared across Apps AV products, so Moments AV and
  Animate AV offerings may also exist in the same project. Do not remove those
  offerings for Series AV; the Series AV release gate is that `default` contains
  `$rc_monthly -> seriesav_pro_monthly` and the private readiness checks pass.

1. Confirm the private Series AV subscription readiness checker passes for both
   preview and production before any App Store/TestFlight submission:

   ```bash
   bun run series-av:subscription:readiness:preview
   bun run series-av:subscription:readiness:production
   ```

2. Confirm Infisical provides `SERIESAV_REVENUECAT_PUBLIC_API_KEY`,
   `SERIESAV_REVENUECAT_OFFERING_ID`, and
   `SERIESAV_REVENUECAT_MONTHLY_PACKAGE_ID` for the submitted environment.
3. Confirm `APPSAV_REVENUECAT_PRODUCT_APP_MAP_JSON` maps
   `seriesav_pro_monthly` to `seriesav`.
4. Confirm visible purchase, restore, and manage-subscription actions match the
   submitted RevenueCat/App Store product configuration.
5. Confirm Pro is framed only around benefits active in this submitted build:
   higher tracking limits, active Pro account access, restore purchases, and
   contextual Avi guidance that already exists in the app.
6. Confirm App Store metadata advertises only the active Pro benefits in this
   submitted build.
7. Confirm App Store review notes explain RevenueCat purchase/restore,
   Account AV access refresh, and the App Store subscription management route.
8. Confirm App Store product mapping, server notifications, and purchase
   reconciliation are ready for the shipping environment before release.

## Release Sign-Off

For the 2026-06-21 App Store submission, these were closed or explicitly
accepted before submit:

1. Guest, signed-in free, and signed-in Pro manual QA were covered by local,
   TestFlight, and private smoke evidence, with real purchase/restore evidence
   deferred to post-submission monitoring.
2. Preview and production signed-in smokes passed.
3. Store metadata matches the submitted build.
4. Public/legal/support/delete-account URLs are reachable.
5. The archive submitted to App Store Connect matches build `1.0 (11)`.
6. App Store Connect submission id:
   `914c99f2-95c6-4b0d-a651-d15433efe639`.

## Native Test Coverage

The iOS project has native XCTest and UI test targets. The latest local run on
2026-06-17 passed 50 tests on the iPhone 17 simulator. Before submission, keep
this target green and add or manually sign off the remaining real-account
flows:

1. Signed-in free Series-only account is eligible and can request deletion after typing `DELETE`.
2. Tune AV linked app blocks deletion.
3. Active Pro access blocks deletion.
4. Completed deletion signs out locally and returns Series AV to guest mode.
