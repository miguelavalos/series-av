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
    guided tracking actions, compact episode-guide progress buttons,
    authenticated `GET /v1/series/{seriesId}` display metadata, and
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
- Web progress UI must not expose free-form manual season/episode inputs.
  Progress moves through guided actions: mark next, previous, clear progress,
  status changes, or selecting a real episode from the backend compact episode
  guide.
- Web Detail may use a backend-curated catalog collection as a non-authoritative
  preview fallback only when the authenticated detail endpoint does not return a
  usable display title for an already-known `seriesId`. It must not rebuild
  detail from free-form text search.
- When Detail resolves canonical display metadata for an entry that was
  previously saved with a technical placeholder title, the web library repairs
  the local title/artwork only for that placeholder case and does not overwrite
  human-readable existing titles.
- Authenticated mobile dark-mode QA on 2026-06-18 covered Detail, Library,
  Search, and Settings at a narrow viewport with Spanish locale. Checks passed
  for no horizontal overflow, no manual episode inputs, no guest copy, no
  visible `avalsys` app UI text, and internal links preserving `?lang`.
- The Series AV web app supports a Settings theme preference with System,
  Light, and Dark modes, plus Series-specific paper, card, border, and text
  color overrides.
- Account and Settings now use a shared Apps AV settings/profile component set
  prepared for reuse across web apps. Series AV is the first app aligned to the
  iOS `AVSettingsProfileScreenScaffold` content model: account, Pro, optional
  cloud sync, account safety, app preferences, tracking, local device data, and
  help/legal sections. Web copy intentionally omits iOS guest product-mode
  references.
- The shared Apps AV web package now also owns reusable Account/Settings
  section primitives for Pro feature rows, cloud sync status, account safety,
  help/legal rows, external buttons, and theme preference helpers. Series AV
  supplies product labels, links, access state, and the Series-specific theme
  attribute only.
- Remaining practical common surfaces were extracted after the Account/Settings
  pass: protected login-first gate, compact sync status, app surface state, and
  base language-preserving path helper now live in Apps AV web. Series AV uses
  them for protected routes, Home empty state, Home/Library sync indicators, and
  internal localized paths while keeping product copy and behavior local.
- The shared AppShell now supports active-route state for desktop and mobile
  navigation. Series AV passes the TanStack current pathname to the shell.
- The internal Apps AV web QA runbook now defines the common route protection,
  language, theme, app shell, Account/Settings, sync, and product-boundary
  checks for Series AV and future product web apps.
- Authenticated browser QA on 2026-06-18 checked `/settings?lang=es` and
  `/account?lang=es`: expected Spanish content rendered, no guest copy was
  present, own links preserved `lang=es`, Free access did not show Pro-only
  cloud sync, and the dark theme selector applied `data-series-theme="dark"`.
- Authenticated browser QA on 2026-06-18 also checked desktop and mobile
  `/library`, `/search`, `/avi`, `/account`, and `/settings` in Spanish:
  active navigation is marked with `aria-current="page"`, own links keep
  `lang=es`, no guest copy is visible, no lowercase `avalsys` is visible in app
  UI, mobile has no horizontal overflow, and the dark theme persists after
  navigation. This exposed and fixed Search using the shared AppShell without
  the current route path.
- Series AV now configures the shared Apps AV web smoke QA runner for the
  signed-out contract across `en`, `es`, `fr`, `de`, and `ca`: `bun run --cwd
  apps/web qa:shared`. It checks public `/`, public `/sign-in`, protected route
  gates including a concrete Detail route, locale preservation on product-owned
  links, HTML language, runtime-error markers, and guest-copy absence against
  `SERIESAV_WEB_QA_BASE_URL` or
  `http://localhost:5193`.
- Functional QA on 2026-06-18 found Preview `/v1/series/popular?surface=search`
  returns one item even when the web requests `limit=12`. The web therefore
  renders one Popular result because the backend curated preview set currently
  has one enriched public series, not because the frontend grid is capped.
- Follow-up QA on 2026-06-18 confirmed Production
  `/v1/series/popular?surface=search&locale=es-ES&limit=12` returns 12 results;
  the one-result Popular grid remains preview-data-only.
- Preview app deploy on 2026-06-18 published the current web parity build to
  `https://app.series-av-preview.avalsys.com`. The shared web smoke passed
  there for `en`, `es`, `fr`, `de`, and `ca` across public `/`, public
  `/sign-in`, protected functional routes, and Detail.
- Production web deploy on 2026-06-18 published the same parity build to
  `https://app.series-av.avalsys.com` after explicit approval. The shared web
  smoke passed there for `en`, `es`, `fr`, `de`, and `ca`, and `/account`,
  `/settings`, and `/series/thetvdb%3A348545` now return 200.
- Validation run after implementation:
  - `bun run --cwd apps/web test`
  - `bun run --cwd apps/web typecheck`
  - `bun run --cwd apps/web build`
  - `bun run --cwd apps/web qa:shared`
  - `SERIESAV_WEB_QA_BASE_URL=https://app.series-av-preview.avalsys.com bun run --cwd apps/web qa:shared`
  - `SERIESAV_WEB_QA_BASE_URL=https://app.series-av.avalsys.com bun run --cwd apps/web qa:shared`
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
