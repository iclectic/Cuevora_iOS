# Cuevora for iOS

Native SwiftUI teleprompter for iPhone and iPad. It uses Cuevora’s name and colours in an interface built for Apple: a tab bar on iPhone, a sidebar on iPad, a writing canvas, and system-style prompter and camera controls. Scripts, settings and recordings stay on the device. There is no account, subscription or sync.

Open `Cuevora.xcodeproj` and run the Cuevora scheme. The deployment target is iOS 17. A development team is still required before a device or App Store build can be signed. App Store uploads need a current Xcode and the iOS SDK Apple requires at submission time.

`swift test` runs the logic tests for playback, backups, recording decisions, speech fallback and accessibility profiles. Those tests do not need a simulator. Camera, microphone, VoiceOver and thermal behaviour still have to be checked on devices. The matrices in `docs/qa/` say what has and has not been run.

The Android source baseline is commit `aedcd6610132c40a16e6e487d44e8d39ba55b529` of [iclectic/Cuevora](https://github.com/iclectic/Cuevora), described in `docs/reference-audit.md`. The product plan is `docs/plans/2026-11-17-feat-cuevora-native-ios-plan.md`.
