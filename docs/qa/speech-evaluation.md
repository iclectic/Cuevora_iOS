# Speech evaluation

Voice commands, adaptive speed and rehearsal reports are implemented and off until the user turns them on. They require on-device recognition for the current locale. Cuevora does not start server recognition when that is unavailable.

These thresholds were set before measurement. None of them has been measured on hardware, so speech is an open parity item for the owner. A failed threshold is not a reason to hide the manual speed control.

| Threshold | Pass | Result |
| --- | --- | --- |
| Quiet-room command rate | At least 18 of 20 scripted commands (`play`, `pause`, `faster`, `slower`, `reset`, `go back`) recognised on one current phone and one older supported phone, en-US or the locale under test | Not measured |
| False commands | Fewer than 1 command in 20 minutes of ordinary speech that was not addressed to the prompter | Not measured |
| Stale or short transcript | Speed stays at the manual value. Covered by `SpeechFallbackTests` | Unit test passed. Not a device test |
| Permission denied, offline, unsupported locale | The screen explains the limit and prompting continues at the set speed | Code review. Not a device test |
| Recognition stops mid take | The user is told. The app does not retry through a server | Code review |
| Microphone shared with video recording | Speech is stopped for the recording. Simultaneous capture is not claimed | Code review |
| Accent, noise, pause and repeated-word sample | At least three speakers, one noisy room and one quiet room, with the transcript labelled as an estimate | Not measured |

Rehearsal figures are labelled estimates. A transcript is written to the device only after Save Report. Discard and leaving the screen drop the unsaved transcript.
