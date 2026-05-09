# Series AV iOS Animation And Media Performance

Series AV is image-heavy and can include playback-adjacent video/trailer
surfaces. UI animation must not add avoidable main-thread or rendering pressure
while posters, metadata, and media surfaces are loading.

## Default Policy

Keep these surfaces static:

- Home/discovery dashboards;
- poster grids and carousels;
- watch list rows;
- progress/library surfaces;
- profile/account screens;
- skeleton/loading cards;
- video/trailer summary surfaces outside the focused player.

Do not use continuous animation in those surfaces:

- no `.repeatForever`;
- no decorative `TimelineView`;
- no shimmer loops;
- no per-poster animated overlays;
- no animated background effects behind dense grids.

## Allowed Animation

Allowed:

- one-shot interaction feedback;
- navigation, sheet, and selection transitions;
- focused trailer/player motion when the player is visible and guarded;
- small macOS/iPad hover effects if they do not loop.

## Runtime Guards

Any continuous media animation must stop unless all are true:

- app scene is active;
- the player/detail surface is visible and focused;
- Reduce Motion is disabled;
- Low Power Mode is disabled.

## Images And Metadata

Poster-heavy screens should keep image work off the main actor:

- downsample posters to the rendered size;
- cache decoded images;
- avoid rebuilding large grids for unchanged metadata;
- avoid animated image replacement in lists/grids;
- dedupe metadata updates before mutating UI state.

## Review Checklist

Before merging UI that touches discovery, library, posters, or playback:

- Search touched files for `repeatForever`, `TimelineView`, and shimmer loops.
- Confirm dense grids/lists remain static.
- Confirm poster decode/downsample does not run on the main actor.
- Build on simulator.
- Test on a real device while scrolling poster-heavy screens.
- If trailer/video playback exists, test navigation and poster loading while
  playback is active.
