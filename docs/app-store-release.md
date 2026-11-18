# App Store release

Checked against Apple's upcoming-requirements page on 18 November 2026. Cuevora is the working name. The store name, icon ownership, and bundle identifier `app.cuevora.teleprompter.ios` still need the owner's confirmation. The reference trademark note says the Cuevora marks belong to the owner.

Version 0.1.0 (build 1) is set on the target. Increase both before an upload. The deployment target is iOS 17. There is no development team in the project.

## What this repository cannot do

- Enrol the Apple Developer membership or create the App Store Connect record. That has to be the owner's account.
- Sign or upload a build. There is no certificate or team id here.
- Publish the privacy policy or the support page. Drafts are in `docs/privacy-policy.md` and `docs/support.md`. They have no public URL yet.
- Take App Store screenshots, file the age-rating questionnaire, or submit.

## Upload rule

Since 28 April 2026, an upload must be built with Xcode 26 or later and the iOS 26 SDK. From April 2027, Apple's page says uploads need the iOS 27 SDK. Recheck that page on the day of the archive. The GitHub simulator job only proves the project compiles. It is not an App Store archive.

The target generates a launch screen (`UILaunchScreen` via the generated Info.plist). Keep that when the archive moves to the iOS 27 SDK, which rejects an upload without one.

## Archive, when a team exists

```sh
xcodebuild -project Cuevora.xcodeproj -scheme Cuevora -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Cuevora.xcarchive \
  DEVELOPMENT_TEAM=YOURTEAM archive
```

Do not run that command in CI until the owner has added the team. The workflow builds the simulator with signing off on purpose.

## TestFlight walk

After the first signed build is on a device, walk these and write the result in `docs/qa/release-matrix.md`.

1. Delete any old copy. Install from TestFlight. Create a script, leave the app, and reopen it.
2. Turn on airplane mode. Edit, prompt, and export a backup to Files.
3. Deny the camera, then the microphone, then speech, then Photos. Each denial should explain itself and leave existing scripts in place.
4. Record a short take, cancel the share sheet, and confirm the file is still in Recordings.
5. Kill Cuevora during an edit and during a recording. The edit should return. A playable partial take should appear, or the app should say recovery failed and keep the file.
6. Import the backup with Cancel, then with Merge. Cancel must not change the library.
7. One iPhone and one iPad, portrait and landscape. VoiceOver through create, prompt, and record is still an open row in the accessibility matrix.

## Reviewer notes

Cuevora has no account and no subscription. Camera and microphone start only after the person taps Record. Speech recognition starts only after voice commands or rehearsal are turned on, and it stays on the device. Photos access is requested only from Save to Photos. Sample script: any text in a new script. The prompter plays with the Play button.

## Store text, ready to edit

**Name:** Cuevora

**Subtitle:** Teleprompter for reading aloud

**Description:** Cuevora scrolls a script while you read. You can keep scripts on this iPhone or iPad, change the speed and text size, and record a video with the words on screen but not inside the file. There is no account and no subscription. Voice commands and rehearsal notes are optional and stay on the device.

**Do not claim:** a measured frame rate, iCloud sync, Android sync, an account, or a subscription.

## Privacy answers to file with the signed build

Match these to `docs/privacy-data-inventory.md` and to `Cuevora/PrivacyInfo.xcprivacy`.

- Tracking: no.
- Data collected by Cuevora: none.
- Camera, microphone, speech recognition, and Photos: used only for the actions in the permission table. Audio for speech is on-device. Disk space is checked so a recording can start or stop, reason `E174.1`, and the number is not sent off the device.
- Third-party SDKs: none.

## Age rating facts for the current questionnaire

The questionnaire itself changed on 31 January 2026 and has to be answered in App Store Connect. Facts from this app: no advertising, no web browser, no social network, no gambling, no purchases, and no account. Scripts are private text the person types. Do not file a rating until those questions are answered on the current form.

## Still required from the owner

- Apple Developer membership and the signing team for `app.cuevora.teleprompter.ios`.
- A public privacy URL and a public support URL, using the drafts or a revision of them.
- Final age rating, iPhone and iPad screenshots, and the store description.
- A decision on the open speech gap in `docs/qa/speech-evaluation.md` and on any recording or accessibility exception found on device.
