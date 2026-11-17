# App Store release

Cuevora is the working name. Confirm the store name, icon ownership and bundle identifier `app.cuevora.teleprompter.ios` before creating the App Store Connect record. The reference trademark note says the Cuevora marks belong to the owner.

## Still required from the owner

- Apple Developer membership and the signing team for this bundle identifier.
- A hosted privacy policy URL and a support URL. The in-app feedback link is `mailto:ibimbraide@gmail.com`, taken from the Android settings screen.
- Final age rating, screenshots for iPhone and iPad, and the store description.
- Reviewer notes that the app has no account and that camera and microphone are used only after the user starts a recording or voice feature.
- A decision on the open speech gap in `docs/qa/speech-evaluation.md` and on any recording exception found in device testing.

## Before upload

- Recheck Apple's current SDK and Xcode requirement. The plan cites Xcode 26 and the iOS 26 SDK for uploads after 28 April 2026. That rule can change.
- Archive from the owner's team, install through TestFlight, and walk `docs/qa/release-matrix.md`.
- Match the privacy answers to `docs/privacy-data-inventory.md` and to the embedded privacy manifest.
- Do not mention subscriptions, accounts, Android sync, iCloud sync, or a measured frame rate.

## Build

The shared scheme is Cuevora. Version 0.1.0 (build 1) is set in the target. Increase it before an upload. Signing is not configured in the project, so an archive needs the owner's team.
