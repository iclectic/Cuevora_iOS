# Android reference audit

Reference: [iclectic/Cuevora](https://github.com/iclectic/Cuevora), commit `aedcd6610132c40a16e6e487d44e8d39ba55b529`. This is a source audit, not a device test. Paths below refer to that repository unless otherwise stated.

## Brand

- `src/index.css` defines light background HSL 0/0%/97%, dark background 244/47%/8%, light primary 263/83%/58%, dark primary 255/93%/76%, and amber brand 38/93%/50% (dark 55%). The native asset catalog carries the background and primary colors in both appearances.
- `public/icons/icon-512.svg` is a purple C with amber script lines and play symbol on a dark indigo rounded square. The checked-in PNG is used for the foundation logo and provisional app icon. The 1024-pixel icon is enlarged from the 512-pixel reference and needs a full-resolution export and visual review before release.
- The reference uses system font stacks and 44-point minimum touch targets. The native shell uses system fonts and native layout.
- `TRADEMARKS.md` identifies Cuevora marks as the owner's and reserves use of them. This implementation follows the owner's request to reuse the identity; confirm ownership and App Store branding before distribution. Source is Apache-2.0; preserve applicable notices if source code is incorporated.

## Feature baseline

| Area | Evidence in reference | Native implementation status |
| --- | --- | --- |
| Library | `src/pages/Home.tsx`: search title/content, tag filter, updated/created/alphabetical/length sort, compact/detailed views, refresh, edit, delete/undo and launch player. | Planned U2. |
| Editor | `src/pages/Editor.tsx`: autosave, tags, word/character counts, read time, text import/export, copy and revision restore. | Planned U2. |
| Models | `src/types/script.ts`: script IDs, title, content, tags, millisecond timestamps, line-index markers and highlights; revision stores content and timestamp. | Planned U2; preserve markers and highlights in interchange even if no editor UI is found. |
| Player | `src/pages/Player.tsx`, `src/hooks/use-prompt-playback.ts`, `src/hooks/use-gesture-controls.ts`: adjustable prompting, themes, focus, mirror, countdown, gestures, keyboard and camera access. | Planned U3/U4. Confirm exact device behavior and gesture conflicts. |
| Recording | `src/pages/RecordMode.tsx`: camera/microphone permission flow, preview, prompting, recording and export. | Planned U4; real device validation required. |
| Rehearsal and voice | `src/pages/Rehearsal.tsx`, `src/lib/rehearsal-metrics.ts`, `src/lib/adaptive-scroll.ts`, `src/hooks/use-voice-control.ts`: speech-dependent metrics, adaptive cadence and commands. | Planned U6; hardware, locale and capture compatibility are unverified. |
| Settings and access | `src/pages/Settings.tsx`, `src/lib/accessibility-profiles.ts`: appearance, defaults, recording, inputs, profiles, data and legal controls. | Planned U5. |
| Identity | `src/lib/auth-context.tsx`: guest mode and conditional Firebase Google/Apple sign-in. Email link explicitly reports that setup is not enabled. `src/lib/sync-service.ts` is a future boundary, not script sync. | Audit account deletion and provider behavior during U8; no sync claims. |

## Backup and data risks

`src/lib/storage.ts` uses `localStorage`, schema version 1, and exports JSON with `version`, `scripts`, `revisions`, `settings`, `rehearsalSessions` and `exportedAt`. Dates are JavaScript milliseconds. It keeps up to ten content revisions per script; deleting a script removes its revisions and undo restores the script only. Its importer normalizes data and writes separate keys, so an iOS importer should not assume the source importer is transactional or that all source fields are represented by the initial plan. Capture real exports as compatibility fixtures and validate before implementing import. Recordings are not included in this JSON export.

## Remaining validation

Run the Android app and compare actual phone screens and interactions with the iOS implementation, including fonts, icon rendering and accessibility. Source inspection alone cannot establish behavior on hardware. Test light/dark contrast and large text in the native app. Verify identity, recordings, speech and backup fixtures on real devices as their implementation units are delivered.
