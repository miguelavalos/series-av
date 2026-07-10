# iOS UI Quality Review

Date: 2026-07-10

Status: completed implementation baseline for the Series AV iOS and iPadOS app.

## Scope

This review covers the native app in `apps/ios`. It focuses on readable product
information, compact actions, predictable navigation, Dynamic Type, iPhone and
iPad layout behavior, recoverable loading states, and regression coverage.

The current visual pass was exercised in Xcode Simulator on iPhone and iPad,
including the largest accessibility text category. Signed-account, purchase,
and production backend validation remain governed by the private AVALSYS native
runtime runbooks and are not replaced by this UI review.

## Implemented Baseline

### App shell and navigation

- iPhone keeps the compact tab shell and iPad uses the sidebar layout.
- iPad sidebar rows, icons, and chrome controls adapt to Dynamic Type instead of
  relying on fixed compact dimensions.
- Settings and account entry points use compact, tappable headers without
  displacing the screen content.

### Home

- The empty state uses separate standard and accessibility layouts so its title,
  explanation, artwork, and primary action remain readable.
- Home discovery has explicit idle, loading, loaded, and failure states. The
  latest successful discovery snapshot is kept for the current app session so
  a refresh failure does not unnecessarily replace usable content.
- Discovery cards scale their artwork, copy, and follow action for accessibility
  text sizes.
- The Avi summary is a compact card at normal text sizes and expands cleanly for
  accessibility text.
- The fixed duplicate `Buscar serie` footer was removed. Home now reserves its
  bottom safe-area bar only while a reversible progress or library action is
  pending.
- The transient undo bar uses semantic Dynamic Type fonts, switches to a
  two-level layout at accessibility sizes, keeps both actions at least 44 points,
  and remains entirely above the floating tab navigation.
- The current-watching hero keeps its compact branded composition normally and
  uses controlled semantic type for status, progress, series title, and next
  episode. At accessibility sizes it removes the decorative foreground poster
  and stacks full-width labelled progress actions instead of compressing copy
  beside icon-only controls.
- The ready-to-start and secondary-watching queues keep dense poster-copy-action
  rows on iPad and use a compact two-level information/action row on iPhone. At
  accessibility sizes, each row gives its title and progress their own readable
  block, then stacks full-width primary and “More options” actions without
  shrinking or truncating their labels.

### Avi

- Avi keeps its circular current-focus and navigation actions plus compact
  metric pills at normal text sizes on both iPhone and iPad.
- At accessibility text sizes, current-focus actions and the Search and Library
  shortcuts become fully labelled, full-width controls instead of relying on
  icons alone.
- Library metrics expand into separate semantic rows that show both their title
  and value. Their type scale is controlled so the rows stay readable without
  becoming oversized at the largest accessibility category.
- Stable identifiers and dedicated UI regressions cover the compact and
  accessibility variants.

### Library and Search

- Library rows stack information and actions on narrow iPhone layouts, retain
  readable metadata, and provide full-size touch targets.
- Library filters remain reachable on iPhone and collapse to an accessible
  selector when the available width or text size requires it.
- Search no longer discards the final item from an odd iPad result set.
- Search cards use available catalog data for a third metadata line: normalized
  series status, latest known season, and known episode count. Unknown provider
  status strings are not exposed directly to users.
- Search metadata is included in the accessibility value as well as the visible
  card.
- Search now uses controlled semantic styles for its complete hierarchy. At
  accessibility sizes, catalog actions move below the metadata and local-library
  actions stack at full width without truncating their labels; the normal iPad
  grid preserves its compact poster-copy-action rows and third metadata line.

### Series detail

- Long summaries can expand and collapse without hiding the rest of the detail
  page.
- The detail header keeps its compact artwork-and-copy column normally, then
  separates poster/title from a full-width summary and guide metadata at
  accessibility sizes, with a controlled high text scale.
- Tracking actions use a compact single-row hierarchy at normal sizes and stack
  three equal-width, fully labelled controls at accessibility sizes.
- The tracking summary uses semantic text styles, keeps status and progress on
  one compact row normally, and stacks them at accessibility sizes so neither
  becomes undersized beside the actions.
- The not-followed tracking state keeps its explanation and a natural-width
  follow action on one compact row normally, then stacks a full-width action at
  accessibility sizes with controlled semantic text.
- The share-invite composer uses controlled semantic text styles, remains
  scrollable, and expands from a medium sheet to a large sheet at accessibility
  sizes so its explanation, editor, counter, and action remain readable.
- The share result uses a dedicated semantic layout and grows from a compact
  168-point sheet to a controlled 270-point accessibility sheet, preserving up
  to three title lines and a full-width 44-point ShareLink action without the
  empty space of a half-screen presentation.
- The progress editor uses controlled semantic styles, separates its hero
  summary from the supporting detail at accessibility sizes, and expands its
  season and episode controls without sacrificing the compact normal layout.
- Upcoming episode cards use controlled semantic styles, let date badges grow
  with accessibility text, and move Library progress actions and Home header
  actions below the copy when horizontal space is constrained. The Home section
  now also owns a persistent container so its initial async load always starts.
- Episode rows use semantic text styles, expose title, air date, and state to
  assistive technologies, and switch to a deliberately stacked layout at
  accessibility sizes without allowing maximum text settings to turn each row
  into a full-screen card.
- The episode-guide footer uses semantic, controlled text styles for the
  remaining-episode count and feedback result; feedback messages also reclaim
  the full card width at accessibility sizes.
- The guide-feedback action keeps a compact icon-title-disclosure row normally
  and switches to a controlled icon-over-title layout at accessibility sizes,
  including its sending, sent, and retryable-error states.
- Episode-guide empty and error states distinguish unavailable data from a
  retryable failure.
- Episode-guide unavailable states retain a compact horizontal presentation
  normally, then stack icon and copy at accessibility sizes; retryable failures
  also expose a full-width labelled retry action.
- Private notes, guide feedback, source links, and library management actions use
  compact rows or menus instead of large repeated buttons.
- The empty private-note action keeps its icon, title, and disclosure affordance
  on one compact row normally, then uses a controlled icon-over-title layout at
  accessibility sizes.
- Saved private notes use a semantic, controlled body style and expose a compact
  44-point edit control instead of a fixed-size label and undersized icon target.
- Secondary-option menus keep compact icon-title-disclosure rows normally and
  switch to matched, controlled icon-over-title layouts at accessibility sizes.
- iPad presents the detail as a wider page with tracking and episode information
  making better use of the available width.

### Incoming share invitations

- The invite-acceptance sheet uses a vertically scrollable state container, so
  sign-in, accepting, accepted, and retryable-error actions remain reachable
  with long localization or service messages.
- Its semantic text scale is controlled at the largest accessibility categories
  without truncating headings, explanations, state messages, or button labels.
- iPhone keeps a concise full-width action hierarchy, while iPad centers the
  content in a readable 620-point column instead of stretching it across the
  whole sheet.
- Dedicated launch scenarios and UI regressions cover the normal guest prompt
  and a long German error at `UICTContentSizeCategoryAccessibilityXXXL`.

### Profile and account deletion

- Guest, Free, Pro, and temporarily unavailable account states have distinct,
  compact presentations.
- The account Profile now scales its screen header, card headings, identity and
  synchronization rows, and settings actions from their original visual sizes
  with controlled Dynamic Type. Standard text retains the previous compact
  density; accessibility text grows without shrinking labels or fixing buttons
  to a single line.
- Compact Free benefits split title and explanation only at accessibility
  sizes, while account-safety and unavailable states expose scaled copy without
  enlarging decorative icons. UI regressions cover Free, Pro, sync conflict,
  action reachability, and the unchanged normal geometry.
- The expanded account-entry panel now uses controlled semantic typography,
  provider buttons whose height grows with their labels, and a real 44/56-point
  skip target. At accessibility sizes the decorative companion is removed and
  the panel becomes scrollable, with its dismissal drag disabled so the consent
  copy and legal links remain reachable.
- Normal iPhone retains the compact illustrated panel, while iPad keeps a wide,
  bottom-aligned presentation. Dedicated UI regressions cover both the compact
  geometry and the maximum-text path through the consent copy.
- The Pro promo-code sheet uses semantic, controlled text styles and a readable
  620-point maximum content width. Standard text keeps the compact field and
  icon action in one row; accessibility text receives a large, scrollable sheet
  with the field and a full-width labelled claim action stacked vertically.
- Dedicated UI regressions cover both promo-code layouts and preserve distinct
  accessibility identities for the title, explanation, field, and claim action.
- Settings language and search-engine menus now scale their labels with
  controlled Dynamic Type. Theme and web-opening choices retain the compact
  horizontal cards at standard sizes, then become readable full-width rows at
  accessibility sizes instead of compressing or truncating their labels.
- The adaptive Settings selectors were checked visually in Simulator on iPhone
  (Spanish standard text and German accessibility text) and iPad, with dedicated
  UI regressions covering both compact and stacked geometry.
- The local-data maintenance sheet keeps its compact medium presentation at
  standard text sizes and expands to full height for accessibility text. Its
  header, explanation, danger heading, and destructive action use bounded
  Dynamic Type so the complete decision remains visible without returning to
  oversized typography.
- Sheet cancellation controls now expose a true minimum 44-point target. The
  local-data sheet and the final Help/Legal account-deletion destination were
  verified in German at maximum accessibility text and covered by dedicated UI
  regressions.
- Help/Legal HTTP and HTTPS destinations now honor the selected web-opening
  preference instead of always escaping to the system. Non-web schemes such as
  support email continue to use the appropriate system handler.
- The in-app browser uses the native Safari controller with persistent
  navigation chrome and an explicit close affordance. Its loaded and native
  failure presentations were checked at standard and maximum accessibility text;
  UI regressions cover Settings routing and the full-height browser surface.
- Profile modal ownership is now represented by one typed destination covering
  the Pro paywall, account deletion, local-data maintenance, and the in-app
  browser. A single item-driven sheet prevents competing presentations and keeps
  test launch destinations deterministic.
- `SeriesProfileScreen` now owns only the profile shell, navigation state, and
  modal routing. Settings and account/Pro/synchronization content live in
  focused view types with explicit inputs, preserving the existing Observation
  ownership and rendered UI.
- Home, Library, Search, and Detail now also use one typed sheet destination per
  screen. Progress, detail, paywall, note, sharing, and browser routes can no
  longer compete through independent presentation state.
- Localized sheet cancellation labels retain natural horizontal width while
  preserving a minimum 44-point target; a regression now guards the complete
  Spanish `Cancelar` label against toolbar clipping.
- The privacy website itself still shows horizontal heading overflow under
  Safari accessibility scaling. This is a web-CSS follow-up and was intentionally
  not changed during the iOS-only pass.
- The native account-deletion flow separates initial-load failures from request,
  finalization, and unlink failures, keeping each error beside the action that
  can recover from it.
- Eligibility, blockers, high-impact consequences, confirmation, keyboard
  dismissal, retry, and cancellation have dedicated UI-test coverage.

### Cloud library safety

- A failed initial cloud pull no longer enables an automatic push of local data.
- Automatic sync remains blocked until a pull succeeds and the local/remote
  merge has an authoritative ETag.
- A failed sync is eligible for retry on the next foreground opportunity even
  when the normal calm-sync interval has not elapsed.
- Explicit user-requested cloud overwrite remains a separate operation and can
  intentionally push without an ETag.

## Localization and accessibility

Visible copy added by this pass is synchronized across Spanish, English,
Catalan, French, and German. New interactive elements expose stable
accessibility identifiers for UI regression tests. Layout tests cover normal and
`UICTContentSizeCategoryAccessibilityXXXL` text sizes where the component shape
changes materially.

## Validation baseline

The 2026-07-10 local validation passed:

- 121 `SeriesAVTests` unit tests;
- 10 focused modal-routing UI regressions covering Search, Library, Detail,
  sharing, Profile, account deletion, paywall, and the in-app browser;
- focused iPhone and iPad UI smoke tests for Home, Library, Search, Avi, detail,
  incoming share invitations, Profile, account deletion, and adaptive text
  layouts;
- a dedicated regression proving that Home exposes one `Buscar serie` action
  and only inserts the bottom bar while an undo action is pending;
- `git diff --check`.

Canonical local commands should continue to use a purpose-named
`-derivedDataPath`, as described in `docs/release-checklist.md`, and remove that
cache after validation.

## Follow-up review order

No high-priority UI or code-structure recommendation remains open from this
review. Future work should be driven by new product behavior or measured runtime
evidence. The external privacy page can still benefit from responsive web CSS at
the narrowest accessibility widths; that belongs to the web project and remains
outside this iOS-only pass.
