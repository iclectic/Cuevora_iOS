# Recording device matrix

No recording in this change was captured on a physical iPhone or iPad. The rows below are the checks still required before a TestFlight build can be treated as verified. Simulator results, when someone runs them, do not replace the device rows.

| Check | Expected | Result |
| --- | --- | --- |
| Front and rear camera, portrait and landscape | Preview matches the interface orientation. The saved file plays upright. The front preview is mirrored. The saved file is not mirrored. | Not run |
| Record, stop, play | Audio and video stay together. The script text is absent from the file. | Not run |
| Switch camera between takes | The next take uses the other camera. Switching is refused while a take is in progress. | Logic test only |
| Phone call, background, multitasking, audio route change | The take stops and a partial file is kept when the writer can finish it. The user is told when recovery fails. | Logic test for the state change. Device timing not run |
| Denied camera or microphone, then allowed in Settings | Recording does not start while access is off. A later attempt can start after access is allowed. | Logic test for the denial message. System Settings path not run |
| Low storage and serious thermal state | Recording does not start. A critical thermal state during a take stops and saves when possible. | Logic test for the refusal. Device not run |
| Share cancelled or failed | The file remains in Cuevora. | Logic test only |
| Save to Photos | Photos access is requested only from that button. Cancelling Photos access leaves the Cuevora file in place. | Not run |
| Headset and Bluetooth microphone | The recorded voice follows the active input. | Not run |
| Long take | The file stays playable and the device does not keep the screen awake after leaving the screen. | Not run |

Output is MPEG-4 (`.mp4`) when AVFoundation accepts that extension. The script overlay is drawn above the preview and is not composited into the movie.
