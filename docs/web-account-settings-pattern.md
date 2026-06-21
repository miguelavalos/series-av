# Series AV Web Account And Settings Pattern

Series AV web follows the shared Apps AV web account/settings pattern documented
in `../../apps-av/docs/web-product-app-patterns.md`.

## Settings

Section order:

1. App preferences: language and appearance.
2. Series tracking: progress model, correction behavior, external-link behavior,
   and source search engine.
3. On this device: browser-local library data and local-data deletion.
4. Help and legal: source, support, privacy, terms, and account deletion links.

The Apple app exposes an in-app versus system-browser preference. On web this is
represented as read-only browser behavior because the browser controls external
link handling.

Settings choice controls use shared `@avalsys/apps-av-web` primitives:
`SettingsOptionButtonGroup` for compact modes and `SettingsSelect` for larger
option lists such as source search engines. Do not add Series-local form styling
unless the control is domain-specific.

## Account

Section order:

1. Account: session, email, and plan.
2. Series AV Pro: Pro account, larger library, and Avi guidance.
3. Cloud sync: shown only when the Account AV capability enables cloud sync.
4. Account safety: shared Account AV deletion flow.

Account plan text should show the actual access tier (`Free` or `Pro`) rather
than a generic connected-account label.

## Shared Product Screens

Series AV web now uses shared Apps AV screen primitives outside account/settings:

- `/library` uses shared search, segmented filters, sync status, empty state, and
  row skeletons. Series-owned code keeps filtering semantics and series rows.
- `/search` uses the shared search field and grid skeleton. Catalog result cards
  stay Series-owned because they depend on posters, TMDb metadata, and library
  follow behavior.
- `/` uses shared metric tiles, grid skeletons, and contextual Avi card. Current
  series progress remains Series-owned.
- `/series/:seriesId` uses the shared segmented control for season selection
  and the shared external-link panel for sources. Episode guide and progress
  mutations remain Series-owned.
