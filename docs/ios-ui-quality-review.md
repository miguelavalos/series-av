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
- Tracking actions use a compact hierarchy at normal sizes and remain usable at
  accessibility sizes.
- Episode-guide empty and error states distinguish unavailable data from a
  retryable failure.
- Private notes, guide feedback, source links, and library management actions use
  compact rows or menus instead of large repeated buttons.
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

Continue the audit one issue at a time. The next known candidate is the transient
undo bar: its normal layout is compact, but its fixed small text and close icon
should be made Dynamic Type-aware with a minimum 44-point interaction target.
