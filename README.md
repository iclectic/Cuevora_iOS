# Cuevora for iOS

Cuevora is a native SwiftUI teleprompter for iPhone and iPad. You write a script, scroll it while you read, and can record a video with the words on screen. The words stay in the prompter. They are not burned into the movie file.

The interface uses Cuevora’s name and colours in an Apple layout: a tab bar on iPhone, a sidebar on iPad, a writing canvas, and system-style prompter and camera controls. Scripts, settings, rehearsal reports, and recordings stay on the device. Cuevora has no account, subscription, or sync.

Open `Cuevora.xcodeproj` and run the Cuevora scheme. The deployment target is iOS 17. A development team is still required before a device or App Store build can be signed. App Store uploads need a current Xcode and the iOS SDK Apple requires at submission time.

## Scripts

The Scripts tab is the library.

- Search matches the title, the text, and the tags.
- Filter by a tag, or sort by recently updated, title, length, or recently created. Pinned scripts stay at the top.
- Pin, delete, and undo a delete until you leave the library. A deleted script’s recordings stay on the device.
- New scripts start from Blank, Introduction, Lesson, or Announcement.
- Script titles, tags, and a short excerpt are indexed for Spotlight on this device.

The editor saves the title, text, and tags after a short pause, and again when you leave the app or the screen. A failed save leaves the draft in the editor. Each script keeps up to ten earlier versions. History can restore one, and the current text is kept as a snapshot when that restore is saved. The editor shows a word count, a character count, and a reading-time estimate from the words-per-minute setting.

From a script you can prompt, record, duplicate, import a UTF-8 text file of 2 MB or less, or export the text. Importing text asks before it replaces what is already there.

## Prompter

Play scrolls the script at the chosen speed. Pause holds the place. Reset returns to the start. Skip moves about ten percent forward or back. The time remaining is an estimate from the words-per-minute setting, and the reading position is saved with the script.

While prompting you can change:

- Speed, from 1 to 10, with a slider and presets.
- Text size, from 16 to 72, and line spacing.
- Theme: Dark, Light, Studio, or High Contrast.
- A countdown of 3, 5, or 10 seconds. Cancelling it does not start playback.
- Mirror text and a focus guide.

Tap the sides to skip. Double-tap to play or pause. Pinch to change the text size. Those gestures can be turned off in Settings. A hardware keyboard uses Space to play or pause, the arrow keys to skip and change speed, M, F, and R for mirror, focus, and reset, and Escape to close.

The screen can stay awake while prompting. Leaving the app pauses playback.

## Recording

Record opens the camera with the script beside or over the preview. Overlay and split view are both available. The front and rear cameras can be switched before a take and after one finishes. Switching during a take is refused.

A countdown can run before the file starts. Standard and High quality are settings. Recording stops if the app goes to the background, the camera or microphone is interrupted, or free space runs low. A finished take, including a partial one, stays in Recordings. Cancelling the share sheet or a refused Photos save does not delete that file. Save to Photos runs only when you tap it.

If Cuevora is killed during a take, the next launch looks for the movie and lists a recovered or partial take when the file is usable.

## Rehearsal and voice

Rehearsal listens with Apple’s on-device speech recognizer and then estimates pace, pauses, filler words, repeated words, and how much of the script was covered. The figures are estimates from the transcript. They are stored only when you tap Save Report. Discard removes the transcript.

Voice commands are off until you turn them on. They recognise play, pause, stop, faster, slower, and reset, including a few longer phrases such as “speed up” and “go back”. Ordinary sentences are left alone. Adaptive speed can follow the same on-device transcript and falls back to the fixed speed when the transcript is missing or stale.

Voice and rehearsal pause while a video is recording, and when you leave the app, so the microphone is not shared with the camera. Cuevora does not switch speech recognition to a server.

## Settings

Settings cover colour mode, reading profile, prompter defaults, recording quality, haptics, gestures, voice, and adaptive speed. Reading profiles raise the text-size and spacing floor: Default, Dyslexia-friendly, Low vision, High contrast, Calm focus, Caption-first, and Simple controls. Prompter defaults can be reset without deleting scripts.

Delete Local Data removes scripts, revisions, rehearsal reports, and recording files from this device. Export a backup first if you want the scripts.

## Shortcuts

Shortcuts can create a script or open the most recently updated one. They open Cuevora. They do not start the camera or microphone.

## Backups

A backup is a JSON file with `format` `cuevora-ios` and `version` 2. It contains scripts, settings, and rehearsal sessions. It does not contain video. Older iOS backups use `version` 1. An Android Cuevora backup uses `version` 1 with script ids, revisions, and settings. Import shows anything the file cannot keep, then waits for Merge, Add Copies, or Replace. Cancel, or a file that fails validation, does not change the scripts already on the device. Merge updates a script when its id matches and leaves the others in place. Replace removes scripts that are not in the file and leaves recordings in place.

## Privacy

Camera, microphone, speech recognition, and Photos add-only access are requested when you start the feature that needs them. Speech stays on the device. There is no analytics or crash reporter. The data inventory is `docs/privacy-data-inventory.md`. Draft pages for the owner to host are `docs/privacy-policy.md` and `docs/support.md`.

## Development

`swift test` runs the logic tests for playback, backups, script drafts, recording decisions, speech, and the release claims. Those tests do not need a simulator. GitHub also builds the app for the iOS Simulator with signing turned off. Camera, microphone, VoiceOver, and thermal behaviour still have to be checked on devices. The matrices in `docs/qa/` say what has and has not been run. This build is not ready for the App Store: signing, a privacy URL, a support URL, and the device gates are still open.

The Android source baseline is commit `aedcd6610132c40a16e6e487d44e8d39ba55b529` of [iclectic/Cuevora](https://github.com/iclectic/Cuevora), described in `docs/reference-audit.md`. The product plan is `docs/plans/2026-11-17-feat-cuevora-native-ios-plan.md`.
