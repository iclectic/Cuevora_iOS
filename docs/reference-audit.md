# Android reference audit

Reference: [iclectic/Cuevora](https://github.com/iclectic/Cuevora), commit `aedcd6610132c40a16e6e487d44e8d39ba55b529`. This is a source audit, not a device test. Paths below refer to that repository unless otherwise stated.

## Brand

- `src/index.css` defines light background HSL 0/0%/97%, dark background 244/47%/8%, light primary 263/83%/58%, dark primary 255/93%/76%, and amber brand 38/93%/50% (dark 55%). The native asset catalog carries the background and primary colors in both appearances.
- `public/icons/icon-512.svg` is a purple C with amber script lines and play symbol on a dark indigo rounded square. The checked-in PNG is used for the in-app logo. The 1024-pixel app icon is rendered from the SVG with an opaque indigo background; confirm its appearance on devices before release.
- The iOS app keeps the Cuevora name, the purple primary, the indigo background and the amber recording accent. Its layout is a native Apple interface: tab bar, inset lists, a writing canvas, and material playback and camera controls. It is not a copy of the Android screens.
- `TRADEMARKS.md` identifies Cuevora marks as the owner's and reserves use of them. This implementation follows the owner's request to reuse the identity; confirm ownership and App Store branding before distribution. Source is Apache-2.0; preserve applicable notices if source code is incorporated.

## Feature baseline

| Area | Evidence in reference | Native implementation status |
| --- | --- | --- |
| Library | `src/pages/Home.tsx`: search title/content, tag filter, updated/created/alphabetical/length sort, compact/detailed views, refresh, edit, delete/undo and launch player. | Implemented in `Cuevora/Features/Library`. Refresh is the system list. Device comparison is still open. |
| Editor | `src/pages/Editor.tsx`: autosave, tags, word/character counts, read time, text import/export, copy and revision restore. | Implemented. Revisions are timestamped snapshots, capped at ten. |
| Models | `src/types/script.ts`: script IDs, title, content, tags, millisecond timestamps, line-index markers and highlights; revision stores content and timestamp. | Stored and drawn. Markers and highlights survive Android import. There is no marker editor in the audited Android pages. |
| Player | `src/pages/Player.tsx`, `src/hooks/use-prompt-playback.ts`, `src/hooks/use-gesture-controls.ts`: adjustable prompting, themes, focus, mirror, countdown, gestures, keyboard and camera access. | Implemented. Vertical speed swipes are replaced by the slider, presets and keyboard because they conflict with scrolling. |
| Recording | `src/pages/RecordMode.tsx`: camera/microphone permission flow, preview, prompting, recording and export. | Implemented. Camera switching during a take is refused. Physical-device checks are listed and not yet run. |
| Rehearsal and voice | `src/pages/Rehearsal.tsx`, `src/lib/rehearsal-metrics.ts`, `src/lib/adaptive-scroll.ts`, `src/hooks/use-voice-control.ts`: speech-dependent metrics, adaptive cadence and commands. | Implemented as opt-in on-device recognition with manual fallback. Measurement thresholds are unmet because they have not been run. |
| Settings and access | `src/pages/Settings.tsx`, `src/lib/accessibility-profiles.ts`: appearance, defaults, recording, inputs, profiles, data and legal controls. | Implemented, including the reference reading profiles. Analytics is omitted because the audited Android source stores the flag and does not send events. |
| Identity | `src/lib/auth-context.tsx`: guest mode and conditional Firebase Google/Apple sign-in. Email link explicitly reports that setup is not enabled. `src/lib/sync-service.ts` is a future boundary, not script sync. | Guest only. Sign-in is labelled unavailable. Local deletion is the deletion control. iCloud sync is designed and switched off. |

## Backup and data risks

`src/lib/storage.ts` uses `localStorage`, schema version 1, and exports JSON with `version`, `scripts`, `revisions`, `settings`, `rehearsalSessions` and `exportedAt`. Dates are JavaScript milliseconds. It keeps up to ten content revisions per script; deleting a script removes its revisions and undo restores the script only. Its importer normalizes data and writes separate keys, so an iOS importer should not assume the source importer is transactional or that all source fields are represented by the initial plan. Capture real exports as compatibility fixtures and validate before implementing import. Recordings are not included in this JSON export.

## Remaining validation

The iOS interface is its own design. Do not treat a visual match with the Android app as a release check. On device, walk the script, prompter, recording and settings flows in light and dark, with large text and rotation, and confirm the brand colours and icon still read clearly.

## Foundation verification

The project targets iOS and iPadOS 17 or later and uses native SwiftUI navigation and system fonts. A simulator-target build is available with Xcode 16.4; App Store submission requires a currently accepted Xcode and SDK. On 2026-11-17, color-token calculations using the reference HSL values gave contrast ratios of 5.24:1 for light primary on background and 7.00:1 for dark primary on background. Reference foreground/background pairs measured 16.73:1 and 17.05:1 respectively. These calculations do not replace contrast checks on rendered controls, camera overlays, different accessibility settings or every color combination.

The iOS app includes the library, editor, prompter, recording, rehearsal, settings and backup flows, laid out as an Apple app rather than a port of the Android screens. The device rows in `docs/qa/` are still open. Logic tests cover backup fixtures, playback, recording decisions and speech fallback.
