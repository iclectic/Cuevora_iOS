# Cuevora for iOS

Native SwiftUI teleprompter for iPhone and iPad. It uses Cuevora’s name and colours in an interface built for Apple: a tab bar on iPhone, a sidebar on iPad, a writing canvas, and system-style prompter and camera controls. Scripts, settings and recordings stay on the device. There is no account, subscription or sync.

Open `Cuevora.xcodeproj` and run the Cuevora scheme. The deployment target is iOS 17. A development team is still required before a device or App Store build can be signed. App Store uploads need a current Xcode and the iOS SDK Apple requires at submission time.

A backup is a JSON file with `format` `cuevora-ios` and `version` 2. It contains scripts, settings, and rehearsal sessions. It does not contain video. Older iOS backups use `version` 1. An Android Cuevora backup uses `version` 1 with script ids, revisions, and settings. Import shows anything the file cannot keep, then waits for Merge, Add Copies, or Replace. Cancel, or a file that fails validation, does not change the scripts already on the device. Merge updates a script when its id matches and leaves the others in place. Replace removes scripts that are not in the file and leaves recordings in place.

`swift test` runs the logic tests for playback, backups, script drafts, recording decisions, speech, and the release claims. Those tests do not need a simulator. GitHub also builds the app for the iOS Simulator with signing turned off. Camera, microphone, VoiceOver and thermal behaviour still have to be checked on devices. The matrices in `docs/qa/` say what has and has not been run. This build is not ready for the App Store: signing, a privacy URL, a support URL, and the device gates are still open. Drafts for the owner to host are `docs/privacy-policy.md` and `docs/support.md`.

The Android source baseline is commit `aedcd6610132c40a16e6e487d44e8d39ba55b529` of [iclectic/Cuevora](https://github.com/iclectic/Cuevora), described in `docs/reference-audit.md`. The product plan is `docs/plans/2026-11-17-feat-cuevora-native-ios-plan.md`.
