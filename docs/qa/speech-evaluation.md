# Speech evaluation

Voice commands, adaptive speed and rehearsal reports stay off until the user turns them on. Listening requires on-device recognition. Cuevora does not start server recognition when that is unavailable, when the network is missing, or when recognition stops. Recording owns the microphone while a take is in progress, and voice commands stay off afterwards until the user turns them on again.

These thresholds were set before measurement. None of them has been measured on hardware, so speech remains an open parity item for the owner. A failed threshold is not a reason to hide the manual speed control.

| Threshold | Pass | Result |
| --- | --- | --- |
| Quiet-room command rate | At least 18 of 20 scripted commands (`play`, `pause`, `faster`, `slower`, `reset`, `go back`) recognised on one current phone and one older supported phone | Not measured |
| Evaluation locales | The sample is planned for `en-US` and `en-GB` only. Another locale is used only when that device reports on-device support. No accuracy is claimed for it. | Not measured |
| False commands | Fewer than 1 command in 20 minutes of ordinary speech that was not addressed to the prompter. A sentence such as “I will play the role” does not count as play. | Parser covered by `SpeechJourneyTests`. Not a device sample |
| Stale, short, silent or low-confidence transcript | Speed stays at the manual value. A transcript below 0.5 confidence does not issue a command. | Unit test passed. Not a device test |
| Permission denied, offline, unsupported locale | The screen explains the limit and prompting continues at the set speed. Offline does not switch to a server. | Logic test. Not a device test |
| Recognition stops mid take | The user is told. The app does not retry through a server. | Logic test for the message. Device timing not run |
| Microphone shared with video recording | Speech stops for the recording and does not resume by itself. Simultaneous capture is not claimed. | Logic test for ownership. Device timing not run |
| Accent, noise, pause and repeated words | At least three speakers, one noisy room and one quiet room. Pauses, fillers and repeated words are shown as estimates. A low-confidence fragment is left out of the estimate. | Repeated-word and noise rules are unit tested. The speaker sample was not run |

Rehearsal figures are labelled estimates. A transcript is written to this device only after Save Report. Discard, Close, and leaving the screen drop the unsaved transcript.
