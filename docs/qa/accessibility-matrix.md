# Accessibility matrix

The interface is English only. `Localizable.xcstrings` has `en` as its source language and does not list another language. System text styles are used outside the prompter. Prompter text has its own size control and also follows the reading profile, Bold Text, and accessibility Dynamic Type sizes.

| Check | Implementation | Device result |
| --- | --- | --- |
| VoiceOver on library, editor, prompter, record and settings | Controls have labels. The script text is an accessibility element. Progress announces an estimated percent. VoiceOver turns prompter gestures off so the buttons remain the way to play, skip and change speed. | Not walked on a device |
| Switch Control and keyboard | Visible buttons exist for play, skip, record and delete. Switch Control also turns gestures off. The prompter accepts a hardware keyboard. | Keyboard path not run on hardware |
| Dynamic Type, including accessibility sizes | Editor and settings use system text. Accessibility sizes raise the prompter text to at least 44 points, including the script over the camera. | Logic test for the size floor. Not rendered on a device |
| Reduce Motion and Increase Contrast | Reduce Motion, and the calm or simple profiles, turn off scroll bounce. The script still moves while prompting. Increase Contrast, or a high-contrast reading profile, uses the high-contrast prompt theme and a thicker focus guide. | Logic test for the decision. Not rendered on a device |
| Colour alone | Play and pause change their label. A selected speed adds the selected trait, and a checkmark when Differentiate Without Colour or high contrast is on. | Logic test for the cue. Not reviewed on a device |
| Touch size | Primary controls request at least 44 by 44 points, including the recorder close, share and delete buttons. | Not measured on device |
| iPad split view, rotation and Stage Manager | A regular-width window uses the sidebar. A compact window uses the tab bar, including an iPad split down to a compact size. The recorder uses a side-by-side layout when wide and a stacked layout when tall. Safe areas hold the prompter and recorder controls. | Layout choice is tested. Rotation and Stage Manager were not run |
| VoiceOver over a camera preview | The preview has a front or rear camera label. The script remains an accessibility element and follows the reading profile. | Not run |
| Haptics | The setting can turn haptics off. Play and pause still change the visible label. | Logic test for the visible label. The tap was not felt on a device |
| Language | Supported language list is English. Settings says the interface is in English. | Catalog test only |

Reading profiles match the reference set: default, dyslexia-friendly, low vision, high contrast, calm focus, caption-first and simple controls. Simple profiles hide the text and spacing sliders and leave play, skip and speed available. Caption-first keeps the time estimate in a larger text style.
