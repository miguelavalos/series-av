# iOS UI Quality Review

Date: 2026-07-10

Status: active implementation baseline for the Series AV iOS and iPadOS app.

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

### Profile and account deletion

- Guest, Free, Pro, and temporarily unavailable account states have distinct,
  compact presentations.
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

- 120 `SeriesAVTests` unit tests;
- focused iPhone and iPad UI smoke tests for Home, Library, Search, detail,
  Profile, account deletion, and adaptive text layouts;
- a dedicated regression proving that Home exposes one `Buscar serie` action
  and only inserts the bottom bar while an undo action is pending;
- `git diff --check`.

Canonical local commands should continue to use a purpose-named
`-derivedDataPath`, as described in `docs/release-checklist.md`, and remove that
cache after validation.

## Follow-up review order

Continue the audit one issue at a time. The next known candidate is the
not-followed tracking card: its explanatory copy still uses a fixed 14-point
font while the follow action is a large full-width button, so the state should
be checked for both accessibility scaling and excessive visual weight.
