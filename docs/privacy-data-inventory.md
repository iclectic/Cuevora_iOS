# Privacy and data inventory

Cuevora on iOS does not require an account. Scripts, settings, rehearsal reports and recordings remain on the device unless the user exports or shares them.

## On the device

- Scripts: title, text, tags, markers, highlights, created and updated times, and up to ten revision snapshots.
- Settings: appearance, prompter defaults, haptics, gestures, voice preference and the last reading position.
- Rehearsal reports: only after the user taps Save Report. The report can include the on-device transcript.
- Recordings: movie files in Application Support, plus a short metadata record. They are not part of the JSON backup.
- Backups: created only when the user exports one.

## Not collected

- No account identifier, contact list, location, advertising identifier or analytics event is sent.
- No Firebase, advertising or subscription SDK is linked.
- Speech audio is handed to Apple's on-device recognizer when the user starts voice commands or a rehearsal. `requiresOnDeviceRecognition` is set. There is no server-recognition fallback.
- Camera and microphone buffers stay in the capture session and the movie file.

## Permissions

| Permission | When it is requested |
| --- | --- |
| Camera | Starting a recording |
| Microphone | Starting a recording, or starting on-device voice commands or rehearsal |
| Speech recognition | Starting voice commands or rehearsal |
| Photos add-only | Tapping Save to Photos |

Sharing a movie file does not request Photos access. Shortcuts do not start the camera or microphone.

## Other copies

- The system share sheet and Files export go where the user sends them.
- iCloud sync is not enabled. A future opt-in would be limited to scripts and settings and would need its own explanation. Recordings would stay local.
- An iCloud device backup made by iOS can include the app's local container. That is the system's backup, not Cuevora sync.

## Deletion

Delete Local Data in Settings removes scripts, revisions, rehearsal reports and recording files from this device. There is no Cuevora account on iOS to delete. The Android reference's email sign-in is not enabled, and its Firebase sign-in is optional and absent from this app.

## Privacy manifest

`Cuevora/PrivacyInfo.xcprivacy` declares no tracking and no collected data types. App Store Connect nutrition labels still have to be answered from the signed build before submission. They are not filed by this repository.
