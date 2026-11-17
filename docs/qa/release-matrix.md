# Release matrix

This build is not ready to upload. The owner still has to supply the Apple Developer membership, signing team, final store name, support URL and privacy URL.

| Gate | State |
| --- | --- |
| Clean simulator build | Configured in `.github/workflows/ios.yml`. Not run in the Linux environment used to write this change |
| Logic tests | `swift test` covers playback, backup, recording decisions, speech fallback and contrast tokens |
| Clean install, upgrade, offline launch | Not run. The previous build's script text, tags and string revisions are still in the SwiftData model so existing libraries can open |
| Denied permissions | Recording and speech explain the block. Not exercised through the system prompts here |
| Data loss | Import validation throws before a document is applied. Replace is a separate confirmation. Share failure does not delete the take |
| Accessibility of core actions | Controls exist. The journey in `accessibility-matrix.md` is not yet walked |
| Capture duration, heat and frame pacing | Frame deltas are clamped in code. No instrumented device trace exists, so no frame-rate or battery number is claimed |
| Privacy review | `docs/privacy-data-inventory.md` matches this code. App Store Connect answers are not submitted |
| TestFlight | Not archived and not uploaded |

Do not submit until a signed build from the owner's team has passed the device rows in the recording, accessibility and speech matrices, or the owner has accepted the open gaps in writing.
