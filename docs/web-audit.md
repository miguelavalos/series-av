# Series AV Web Audit

Status: current as of 2026-06-18.

Series AV commercial web and Series AV web app were checked as part of the AV
web visual audit.

## Contract

- User-facing web content supports `en`, `es`, `fr`, `de`, and `ca`.
- AV-owned links preserve the active language.
- The interactive web app exposes a public informational `/`, requires login for
  functional product routes, and does not expose guest-mode product
  functionality in signed-out app areas.
- The app surface avoids visible lowercase `avalsys` except where legal or
  commercial context requires company naming.

## Latest Audit Result

- 2026-06-18 parity implementation ported the signed-in web app from static
  shells to functional Series AV iOS parity slices:
  - web library model now matches `SeriesLibraryEntry` fields used by iOS:
    entry id, series id, title, status, episode cursor, pin, artwork, archive,
    delete, add/update/interacted timestamps;
  - web helpers now cover mark next, previous, watched through, clear progress,
    status changes, pin, archive, restore, soft delete, search, active/archive
    snapshots, and Free/Pro active limits;
  - signed-in web library state loads from a per-account local browser cache,
    then syncs with `/v1/apps/seriesav/data/seriesLibrary` using the Account AV
    session token, ETag, and iOS pull-merge-push strategy;
  - Search keeps `/v1/series/search`, uses `/v1/series/popular` when available,
    distinguishes local library matches from catalog results, and follows
    catalog titles into the signed-in library;
  - `/series/$seriesId` is a protected detail route with metadata, artwork,
    tracking actions, compact progress editor, and
    `/v1/series/{seriesId}/episodes`;
  - Library shows real active and archived sections, local search, filters,
    status/progress/pin/archive/restore/delete actions;
  - Home shows real continue-watching state, next episode, counts, sync state,
    and an empty state linked to Search;
  - Avi uses the current library focus and runs real library actions only;
  - Account and Settings routes expose account identity, plan/limit, sync
    status, Account AV plan/account deletion links, sign out, language links,
    local browser data clearing, legal, and support.
- Web intentionally does not implement iOS guest product mode. Functional
  routes remain wrapped in signed-in protection; signed-out users see only login
  and public informational surfaces.
- Web Pro management intentionally links to Account AV management instead of
  inventing web billing or purchase flows.
- Authenticated QA on 2026-06-18 confirmed that app-data sync must use the
  Account AV API, not the Series catalog API. `seriesLibrary` remains
  Account-owned user data at `/v1/apps/seriesav/data/seriesLibrary`; Series API
  remains catalog/search/episodes only.
- The signed-in app now keeps iOS-style simplicity on web: primary episode
  progress actions stay visible, while secondary library actions are grouped in
  a compact menu instead of exposed as a full row of buttons.
- The Series AV web app supports system dark mode with Series-specific paper,
  card, border, and text color overrides.
- Validation run after implementation:
  - `bun run --cwd apps/web test`
  - `bun run --cwd apps/web typecheck`
  - `bun run --cwd apps/web build`
- Commercial desktop and mobile browser QA passed.
- Web app desktop and mobile browser QA passed.
- Protected app routes require sign-in and keep `?lang` on redirects.
- The commercial Apps AV CTA was adjusted to preserve the active locale.
- Preview app legal/support/account links should use preview URLs when those
  URLs exist; production links from preview are allowed only as documented
  temporary exceptions until matching preview targets exist.
- The preview web app build no longer emits the large client chunk warning:
  vendor chunks are split for Clerk, serialization, UI, and app bootstrap while
  keeping the same public `/`, sign-in, and protected-route behavior.
- The production web app was deployed at `https://app.series-av.avalsys.com`.
  Production QA exposed app-owned CTAs and Avi/footer links that dropped
  non-English `?lang`; the app now localizes those links before shell, footer,
  sign-in, and product CTAs render.
