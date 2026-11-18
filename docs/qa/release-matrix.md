# Release matrix

Checked on 18 November 2026. This build is not ready to upload. `ReleaseClaims.readyToUpload` stays false until the owner supplies a signing team, hosted privacy and support URLs, and the device gates below are passed or accepted in writing.

| Gate | State |
| --- | --- |
| Logic tests | `.github/workflows/ios.yml` runs `swift test` on Ubuntu with Swift 6.0.3. The suite covers playback, backups, recording decisions, speech, and the release claims. |
| Simulator build | The same workflow builds the Cuevora scheme for the generic iOS Simulator with code signing off. It does not boot a simulator or run a UI-test target. Journey checks live in `swift test` because there is no UI-test host. |
| Signed archive | Not configured. The project has no `DEVELOPMENT_TEAM`. An archive has to be made on the owner's team. The command is in `docs/app-store-release.md`. |
| Clean install, upgrade, offline launch | Not run on a device. The SwiftData model still opens an existing library. Offline use does not call Cuevora servers. |
| Denied permissions | The permission sentences are in the target. Recording and speech explain a denial. The system prompts were not tapped here. |
| Restart, long session, export | Save-on-background and backup round-trip are covered in logic tests. A killed app, a long recording, and a device export were not run. |
| Data loss | Import validation fails before anything is applied. Replace asks first. A failed share does not delete the only take. |
| Accessibility | Controls exist. The device walk in `docs/qa/accessibility-matrix.md` is still open. Pull request #8, which tightens those settings, is not on `main`. |
| Capture, heat, frames | Frame deltas are clamped. No device trace exists, so no frame rate, battery, or temperature number is claimed. See `docs/qa/recording-device-matrix.md`. |
| Speech sample | Thresholds are set and not measured. See `docs/qa/speech-evaluation.md`. |
| Privacy | The inventory, the draft policy, and `Cuevora/PrivacyInfo.xcprivacy` agree: no tracking, no collected data types, and disk space reason `E174.1` only. App Store Connect answers are not filed. |
| TestFlight | Not archived and not uploaded. The walk to run after the first build is in `docs/app-store-release.md`. |
| SDK rule | On 18 November 2026, Apple's upcoming-requirements page still required Xcode 26 or later and the iOS 26 SDK for uploads, in force since 28 April 2026. From April 2027 the page says uploads need the iOS 27 SDK. This repository has not produced that archive. |

Do not submit until a signed build from the owner's team has passed the device rows, or the owner has accepted the open gaps in writing.
