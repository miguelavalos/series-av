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
5. Confirm the shipping version and build number are correct for App Store Connect. `1.0 (1)` is acceptable only if this is the first uploaded build for version `1.0`; otherwise increment `CFBundleVersion`.

## Manual QA

Because the iOS project currently has no native test targets, complete and sign off this manual smoke before release.

### Guest

1. Launch app from clean install.
2. Dismiss onboarding and continue as guest.
3. Verify Home loads featured rows and continue-watching state without crash.
4. Search for at least one known show and open detail.
5. Add a show to library and confirm it appears in `Biblioteca`.
6. Open `Próximos` and verify next-up content renders.
7. Open `Perfil` and confirm privacy, terms, support, source code, and TVMaze data-source attribution are visible.

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
5. Confirm cloud library sync runs and status updates in profile.
6. Confirm shared lists load, open, add item, and remove item.
7. Confirm recommendations load and status changes persist.
8. Confirm signed-in search/detail can resolve backend-backed catalog data where expected.

### Production Signed-In Smoke

1. Run preview smoke against a real signed-in Account AV session token:

   ```bash
   bun run verify:cloudflare:signed-in:preview:prompt -- --mode signedInFree
   bun run verify:cloudflare:signed-in:preview:prompt -- --mode signedInPro
   ```

2. Run production smoke against a safe real account:

   ```bash
   bun run verify:cloudflare:signed-in:production:prompt -- --mode signedInFree
   bun run verify:cloudflare:signed-in:production:prompt -- --mode signedInPro
   ```

3. Confirm `signedInFree` and `signedInPro` capability boundaries still match the shipped product copy.

## App Store And Account Compliance

1. Confirm App Store Connect privacy policy URL points to `https://series-av.avalsys.com/privacy`.
2. Confirm the delete-account support URL is `https://series-av.avalsys.com/delete-account`.
3. Confirm review notes explain the shared Apps AV account-deletion flow, linked-app blockers, and provider-managed subscription caveat.
4. Confirm the build exposes the native in-app route at Profile > Account safety > Delete Apps AV account.
5. Confirm store metadata does not promise cloud sync, Pro social, Avi actions,
   or purchase flows that are not active in the submitted build.
6. Confirm TVMaze attribution remains visible in-product.
7. Confirm any visible TV/movie posters are supported by provider terms,
   attribution, and release evidence.
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
5. Confirm Pro is framed as account-backed access for higher limits, Pro sync
   readiness, and the future social base only where those features are active or
   explicitly future-facing.
6. Confirm App Store metadata advertises only the active Pro benefits in this
   submitted build.
7. Confirm App Store review notes explain RevenueCat purchase/restore,
   Account AV access refresh, and the App Store subscription management route.
8. Confirm App Store product mapping, server notifications, and purchase
   reconciliation are ready for the shipping environment before release.

## Release Sign-Off

Do not submit until these are true:

1. Guest, signed-in free, and signed-in Pro manual QA are signed off.
2. Preview and production signed-in smokes pass.
3. Store metadata matches the exact shipped behavior.
4. All public/legal/support URLs are reachable.
5. The archive submitted to App Store Connect matches the reviewed build.

## Native Test Gap

The iOS project currently has no native unit or UI test targets. Before submission, add an XCTest target or complete manual backend-fixture QA for:

1. Signed-in free Series-only account is eligible and can request deletion after typing `DELETE`.
2. Tune AV linked app blocks deletion.
3. Active Pro access blocks deletion.
4. Completed deletion signs out locally and returns Series AV to guest mode.
