---
title: "Build Cuevora for iOS and iPadOS"
type: feat
date: 2026-11-17
---

# Build Cuevora for iOS and iPadOS

## Summary

Build a free, native Swift teleprompter for iPhone and iPad with the full functional scope and recognizable identity of the Android Cuevora app. Add Apple-specific experiences that improve the product, validate the complete experience on physical devices, and prepare it for App Store review.

## Problem Frame

The reference [Cuevora repository](https://github.com/iclectic/Cuevora) describes a React/Capacitor product with local scripts, a configurable player, recording, accessibility options and optional voice features. Its README is an inventory of intended behavior, not proof that every feature works on every device. This iOS repository currently has no application code. Native iOS work is a new implementation, and the reference's styling, actual behavior, assets and backup schema must be examined before being copied. The name Cuevora is assumed; confirm the final store name and rights before release.

## Requirements

- R1. Provide free access to all shipped capabilities without subscriptions, paywalls, forced accounts, watermarks or artificial script and recording limits. Device storage, system permissions and hardware capabilities still apply.
- R2. Preserve Cuevora's recognizable logo, colors, visual hierarchy and main workflows while respecting iOS and iPadOS interaction conventions.
- R3. Create, edit, search, sort, tag, duplicate, delete with undo, and resume locally stored scripts; autosave reliably and offer revision history and writing statistics.
- R4. Import and export plain text and offer a validated, versioned backup and restore path, including verified Android backup compatibility when feasible.
- R5. Provide smooth, controllable prompting with speed, seeking, countdown, themes, typography, focus guide, mirror, progress and session recovery.
- R6. Record camera video and audio while prompting; preview, retain and share or explicitly save completed recordings with clear handling of interruptions and failures.
- R7. Support accessible touch controls, hardware keyboard, VoiceOver, Dynamic Type, contrast, Reduce Motion and adaptable iPad layouts. Provide meaningful equivalents for reference gestures and accessibility profiles.
- R8. Offer voice commands, adaptive cadence and rehearsal reports only where device, language, permissions and measured reliability support them; preserve fixed-speed and manual controls.
- R9. Keep scripts and recordings local by default, make permissions contextual, explain data handling and provide export and deletion controls. Do not imply account-based sync exists.
- R10. Ship a tested, signed build, accurate privacy disclosures, support and marketing materials, and an App Store submission.
- R11. Audit every user-visible Android feature and account-related flow against the pinned reference. Implement each working feature or an equivalent native experience, track evidence in a parity matrix, and identify any release exception explicitly for owner review.
- R12. Add useful Apple integrations, including Files, Share Sheet, iPad multitasking and App Shortcuts, and assess optional iCloud synchronization as described below. All added features remain free.

## Scope and Parity

| Reference capability | iOS target |
| --- | --- |
| Library, tags, search, sorting, quick resume | Launch; use native list and context menus. |
| Editor, save status, statistics, ten revisions | Launch; revisions are explicit durable snapshots, with bounded storage. |
| Text import/export and JSON backup | Launch; Android restore requires schema and fixture verification in U2. Never silently claim compatibility. |
| Speed presets and continuous adjustment, mirror, focus line, countdown, four themes, type and spacing | Launch; match reference ranges where meaningful after usability testing. |
| Gestures, keyboard, haptics | Launch with discoverable buttons and accessibility alternatives; avoid conflicts with iOS gestures. |
| Camera overlay, split view, camera switching, preview and share | Launch; support switching between takes, and only during a take if device testing proves uninterrupted capture reliable. |
| Voice commands, cadence following, rehearsal reports | Required parity targets in U6 on supported devices and languages, with manual fallback and explicit availability. A quality failure is an open parity issue for owner review, not silent removal. |
| Optional Firebase identity, email setup, account deletion | Audit working Android flows and reproduce working optional identity and deletion behavior where applicable, without requiring sign-in or implying sync. Prepared or disabled flows stay accurately labeled until implemented and tested. |
| Apple-specific integrations | Files and Share Sheet, iPad multitasking and keyboard, and useful App Shortcuts are planned additions. Assess optional iCloud sync and other integrations in U8. |
| Android live sync, collaboration, AI, external displays, Watch remote | Future candidates; do not represent these as existing Android features. |

## Key Technical Decisions

- **Swift and SwiftUI:** Use SwiftUI for navigation, library, editor and settings, with UIKit bridges where precise text layout, scrolling, keyboard or capture preview requires them. Use structured concurrency and isolate mutable capture and persistence state. Avoid a WebView wrapper.
- **Deployment:** Start with iOS/iPadOS 17 as a planning baseline, validate audience and dependencies before project setup, and support iPhone and iPad in portrait and landscape. The SDK used to build is separate from the minimum OS. Recheck Apple's requirements before submission.
- **Local persistence:** Use a versioned SwiftData model for scripts, revisions and settings, with atomic saves, migration tests and clear recoverable errors. Keep recordings as files with persistent metadata; do not put large video blobs in the database. Validate backup sizes and schema before any mutation; restore transactionally with an explicit merge/replace choice and no destructive partial restore.
- **Playback engine:** Use elapsed monotonic time and display-synchronized updates, independent of refresh rate; define speed in stable units, preserve position across layout and font changes, clamp seek, and pause on interruption. Do not promise 60 fps without measurements. Keep the device awake only during active prompting/recording and restore the prior idle behavior on exit.
- **Capture:** Use AVFoundation with a single owned capture session and a coordinated audio session. Script and controls are a preview overlay, not burned into the recorded video. Output a broadly shareable native format after validating device capabilities. Request Photos access only for an explicit save-to-Photos action, using the least access needed; sharing a file should not require it.
- **Speech privacy:** Prefer on-device recognition when supported; do not silently fall back to server recognition. If unavailable, explain the limitation and use manual/fixed-speed prompting. Simultaneous capture and speech input is a feasibility gate, not an assumption. Never make claims about transcript accuracy or offline processing without verification.
- **Brand and design:** Inventory source assets, typography, token values, screenshots and trademark terms; map them to an asset catalog and semantic light/dark colors. Reuse authorized originals where suitable, produce correct iOS icon variants, and test readability over camera previews.
- **Privacy and optional identity:** Core use requires no account. Keep scripts, audio and video local by default; explicit sharing, opt-in sync and eligible OS backups are distinct data paths to explain. Audit optional identity separately from script sync. If authentication or diagnostics SDKs are added, document their actual data flows, deletion behavior and App Store privacy declarations.

## Implementation Units

Paths below are proposed for this empty repository and can be adjusted when the Xcode project is created. Each unit includes tests in its scope.

### U1. Reference audit and product foundation

- **Files:** `docs/reference-audit.md`, `Cuevora.xcodeproj`, `Cuevora/App/`, `Cuevora/DesignSystem/`, `Cuevora/Assets.xcassets/`, `CuevoraTests/DesignSystemTests.swift`.
- **Work:** Pin a source commit; inspect actual pages, storage/backup code, visual tokens, icon files, license and trademark guidance. Capture screen and workflow comparisons and a parity matrix covering each visible feature, exact behavior, native implementation, device constraints and test evidence. Distinguish implemented functionality from placeholders. Build navigation shell, accessible semantic styles and asset catalog; define supported devices and versions.
- **Verify:** Confirm asset provenance and color contrast; compare library, editor, player, recording and settings against Android on phone and iPad in light/dark, large text and rotation. Verify clean build and accessibility labels. No exact color or feature claims until the audit is done.

### U2. Scripts, persistence and portability

- **Files:** `Cuevora/Models/`, `Cuevora/Persistence/`, `Cuevora/Features/Library/`, `Cuevora/Features/Editor/`, `Cuevora/Features/Backup/`, `CuevoraTests/PersistenceTests.swift`, `CuevoraTests/BackupTests.swift`, `CuevoraUITests/ScriptJourneyTests.swift`, `CuevoraTests/Fixtures/`.
- **Work:** Implement script metadata, tags, timestamps, bounded revisions, draft saving and quick resume. Define save on debounce, background and navigation; surface failure and preserve edits for retry. Add text import/export and a documented versioned backup. Inspect Android source and generate real fixtures before implementing an Android importer; preserve supported content and report unsupported fields before confirmation. Keep existing data untouched on validation failure. Export user-generated data with a clear scope including whether video is excluded.
- **Verify:** Create/edit/kill/relaunch, rapid typing, save failure, revision restore and undo deletion; handle Unicode, empty and long scripts. Test older schemas, malformed/oversized files, duplicate IDs, newer versions and interrupted restore. Round-trip iOS backups and real Android fixtures; confirm merge/replace behavior and no data loss.

### U3. Prompting engine and controls

- **Files:** `Cuevora/Features/Player/`, `Cuevora/Services/Playback/`, `CuevoraTests/PlaybackEngineTests.swift`, `CuevoraUITests/PlayerJourneyTests.swift`.
- **Work:** Implement deterministic player states, monotonic elapsed-time motion, speed presets and slider, pause/resume, seek, reset, countdown, mirror, focus, themes, font and spacing. Calculate progress and remaining time with labeled estimates. Preserve logical reading position when layout changes. Provide tap and gesture controls alongside visible accessible actions and hardware shortcuts; keep the screen awake only while needed.
- **Verify:** Simulate varying frame intervals, background/foreground, rotation, Dynamic Type, end of script, seek boundaries, countdown cancellation and adjustment mid-play. Test long text, one-line text, RTL and mixed Unicode. Measure frame pacing and heat on representative hardware; no runaway jump after interruption. Test all controls with VoiceOver and a keyboard.

### U4. Recording and export

- **Files:** `Cuevora/Services/Capture/`, `Cuevora/Features/Recording/`, `CuevoraTests/RecordingStateTests.swift`, `CuevoraUITests/RecordingJourneyTests.swift`, `docs/qa/recording-device-matrix.md`.
- **Work:** Implement preview, front/rear selection, prompt overlay and split layouts, countdown, record/stop, playback, file management and system share. Explicitly save to Photos only on request. Handle camera/microphone denial, unavailable hardware, interruptions, phone calls, backgrounding, audio route changes, low space, thermal pressure and app termination. Finalize a valid partial take where possible and tell the user when recovery fails. Never delete the only good take on share failure.
- **Verify:** Mock permission and state transitions; on physical devices record and play audio/video in both orientations, switch cameras between takes, interrupt, deny/re-enable permissions, fill storage and cancel share. Check output orientation, synchronization, mirroring semantics, file cleanup and that scripts are absent from video. Test headset/Bluetooth routes and long takes under thermal load.

### U5. Accessibility and native polish

- **Files:** `Cuevora/Features/Settings/`, `Cuevora/DesignSystem/`, `CuevoraUITests/AccessibilityJourneyTests.swift`, `docs/qa/accessibility-matrix.md`.
- **Work:** Implement system/light/dark appearance, prompting defaults, haptics toggle and useful reading profiles. Support system accessibility settings and a simpler control mode; never rely solely on color, gestures or haptics. Adapt iPad split view, safe areas, keyboard and rotation. Localize the architecture and ship verified initial English strings; do not imply unsupported languages.
- **Verify:** Walk complete library-to-record journey with VoiceOver, Switch Control, Dynamic Type accessibility sizes, Reduce Motion, increased contrast and keyboard. Check focus order, minimum touch targets, legibility over video, clipping and accessibility announcements on compact iPhone and multitasking iPad.

### U6. Speech and rehearsal feasibility

- **Files:** `Cuevora/Services/Speech/`, `Cuevora/Features/Rehearsal/`, `CuevoraTests/SpeechFallbackTests.swift`, `docs/qa/speech-evaluation.md`.
- **Work:** Prototype opt-in on-device speech recognition, commands, cadence adjustment and local rehearsal metrics with shared audio ownership. Define supported locale/device matrix and evaluate accented voices, pauses, background noise and repeated words. Provide immediate manual override and distinguish estimates from facts. Only retain recordings or transcripts when the user chooses and disclose retention.
- **Verify:** Test denied permission, offline, unsupported locale, unavailable recognizer, loss of recognition, microphone contention, silence, false commands and app interruption. Run a documented real-device sample across speakers and environments. Set quantitative thresholds before evaluation; resolve failed thresholds before release or bring the specific remaining parity gap to the owner for a release decision.

### U8. Apple integrations and optional identity

- **Files:** `Cuevora/Features/Integrations/`, `Cuevora/Services/Sync/`, `Cuevora/Services/Identity/`, `CuevoraTests/AppleIntegrationTests.swift`, `CuevoraTests/SyncTests.swift`, `CuevoraUITests/IntegrationJourneyTests.swift`, `docs/qa/parity-matrix.md`.
- **Work:** Integrate Files document picking and native sharing, iPad multitasking and keyboard navigation. Add App Intents for creating a script and opening the most recent script, with explicit user interaction before camera or microphone use. Audit the Android identity flows and implement working equivalents, including account deletion if accounts are created, while retaining guest access. Evaluate opt-in iCloud script and settings sync as a free Apple-specific addition; design schema and consent before enabling it. Recordings remain local unless a separate explicit feature is designed. Consider external displays, Watch remote and widgets only after core parity.
- **Verify:** Exercise Files import/export, canceled shares, iPad resize, hardware keyboard and Shortcuts from supported contexts. Test identity unavailable/offline, sign-out, deletion and guest data preservation. For any iCloud release, test opt-in/out, no iCloud account, offline edits, concurrent edits, conflict handling, deletion propagation, storage limits, account changes and recovery on two physical devices; explain what syncs and never claim Android synchronization.

### U7. Quality, privacy and release

- **Files:** `CuevoraTests/`, `CuevoraUITests/`, `docs/qa/release-matrix.md`, `docs/privacy-data-inventory.md`, `docs/app-store-release.md`, `README.md`, `.github/workflows/ios.yml`.
- **Work:** Add reproducible simulator build and unit/UI checks in CI, signed archive workflow, crash/error review that does not collect user content, and a real-device TestFlight plan. Document data flows, retention, backups, permission strings, privacy manifest and required-reason API use where applicable. Prepare hosted privacy and support URLs, App Store privacy answers, age rating, screenshots, icon, descriptions and reviewer notes. Set up the developer membership, identifiers, signing and App Store Connect record under the owner's account. Verify current Apple requirements immediately before upload.
- **Verify:** Test clean install, upgrade and restore, offline launch, denied permissions, restart, long sessions and export across supported devices/OS versions. Check archive on a device, TestFlight journeys and actual App Store metadata. Reconcile disclosures against the final build and third-party manifests. Submit only after release gates pass and the owner has supplied account and legal details.

## Delivery Sequence and Release Gates

1. **Foundation:** U1 establishes the pinned reference, branding, platform baseline and measurable acceptance fixtures.
2. **Core:** U2 and U3 deliver a usable offline script-to-prompt journey. Exit when restart, backup, smooth scrolling and accessibility basics work on real devices.
3. **Production capture:** U4 builds on the player; U5 runs alongside it. Exit when complete takes survive common interruptions and the end-to-end accessible journey works.
4. **Full parity and Apple integrations:** U6 and U8 follow capture and persistence integration. Close the reference parity matrix and test Apple-specific features; escalate any unavoidable platform or quality exception for owner review.
5. **Beta and release:** U7 exercises all included features in TestFlight, fixes defects and prepares submission. An owner-controlled developer account, signed build, valid URLs, real-device testing and correct disclosures are release dependencies.

Quality gates: zero known data-loss or unusable-recording defects; no crashes or blocked core journeys in the agreed device matrix; accessible operation of every core action; correct offline behavior; measured smoothness and battery/thermal results documented for representative older and current devices; and successful import/export and privacy review. Establish numeric frame, startup, capture-duration and speech thresholds from baseline devices before beta, then record results and exceptions; avoid presenting unmeasured targets as guarantees.

## Risks and Decisions to Confirm

- **Brand and naming:** The user calls the app Cuevora. The plan uses Cuevora provisionally. Confirm the App Store name, ownership of icon assets and desired visual fidelity before shipping.
- **Cross-platform data:** README describes JSON backup, but its real format, encoding, field versions and migration guarantees have not yet been inspected. Compatibility is conditional on U2 fixtures and explicit loss reporting.
- **Speech and capture:** On-device recognition support varies by language and hardware; simultaneous speech and recording may not meet reliability or privacy goals. U6 is a gate, not a promise.
- **iPad and minimum OS:** iOS 17 and iPad support are recommended defaults; validate against the intended audience and available test hardware before implementation.
- **Schedule and cost:** No credible date follows from a README alone. Estimate after U1 and a capture/speech spike, accounting for physical devices, Apple Developer membership, design, testing, legal URLs and App Review. Free features still have ongoing maintenance costs.

## Sources

- [Cuevora reference repository and README](https://github.com/iclectic/Cuevora): feature and design inventory; inspect source and pin a commit before implementation.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/guidelines/): review current rules and privacy obligations at submission.
- [Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a): since April 28, 2026, uploaded iOS apps require Xcode 26 or later and the iOS 26 SDK or later; requirements can change.
- [App Store Connect build upload](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/): current build and upload requirements.
- [Preparing a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/): reviewer information and test access.
- [AVFoundation capture errors](https://developer.apple.com/documentation/avfoundation/averror-swift.struct): capture interruptions and failure states must be handled.
- [Apple App Intents](https://developer.apple.com/documentation/appintents): expose supported actions to system experiences such as Shortcuts.
- [SwiftData and iCloud](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices): iCloud synchronization requires compatible models and configured capabilities.
- [On-device speech availability](https://developer.apple.com/documentation/Speech/SFSpeechRecognizer/supportsOnDeviceRecognition): check support before requiring local recognition.
