# Recording device matrix

No recording in this change was captured on a physical iPhone or iPad. The rows below are the checks still required before a TestFlight build can be treated as verified. Simulator results, when someone runs them, do not replace the device rows.

| Check | Expected | Result |
| --- | --- | --- |
| Front and rear camera, portrait and landscape | Preview matches the interface orientation. The saved file plays upright. The front preview is mirrored. The saved file is not mirrored. | Not run |
| Record, stop, play | Audio and video stay together. The script text is absent from the file. | Not run |
| Switch camera between takes | The next take uses the other camera. Switching is refused while a take is in progress. | Logic test only |
| Phone call, background, multitasking | The take stops and a partial file is kept when the writer can finish it. The user is told when recovery fails. A countdown in progress is cancelled and does not start after Cuevora returns. | Logic test for the state change. Device timing not run |
| Audio route change, headset, Bluetooth microphone | Recording continues on the input that is still available. The recorded voice is expected to follow that input. | Logic test that a route change does not stop the take. Device route not run |
| Denied camera or microphone, then allowed in Settings | Recording does not start while access is off. A later attempt can start after access is allowed. | Logic test for the denial message. System Settings path not run |
| Low storage and serious thermal state | Recording does not start. Storage running out during a take, or a critical thermal state, stops and saves when possible. | Logic test for the refusal and the mid-take stop. Device not run |
| Share cancelled or failed | The file remains in Cuevora. | Logic test only |
| Save to Photos | Photos access is requested only from that button. Cancelling Photos access or a failed save leaves the Cuevora file in place. | Logic test for the keep-file decision. The system permission dialog was not run |
| App termination during a take | A `.writing` marker is recovered on the next open of Recordings or the recorder. A playable file becomes a partial take. An unreadable file stays on the device and is marked as not recovered. | Decision covered by logic tests. A killed-app file has not been produced here. |
| Long take | The file stays playable and the device does not keep the screen awake after leaving the screen. | Not run |

Output is MPEG-4 (`.mp4`) when AVFoundation accepts that extension. The script overlay is drawn above the preview and is not composited into the movie.
