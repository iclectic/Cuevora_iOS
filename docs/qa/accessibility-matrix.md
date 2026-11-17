# Accessibility matrix

The interface is English. System text styles are used outside the prompter. Prompter text has its own size control and also respects a reading profile and accessibility Dynamic Type sizes.

| Check | Implementation | Device result |
| --- | --- | --- |
| VoiceOver on library, editor, prompter, record and settings | Controls have labels. The script text is an accessibility element. Progress announces an estimated percent. | Not walked on a device |
| Switch Control and keyboard | Visible buttons exist for play, skip, record and delete. The prompter accepts a hardware keyboard. | Keyboard path not run on hardware |
| Dynamic Type, including accessibility sizes | Editor and settings use system text. Accessibility sizes raise the prompter text to at least 44 points. | Not run |
| Reduce Motion and Increase Contrast | Calm and simple profiles reduce reliance on motion. Increase Contrast is left to the system for controls. Prompt themes already use light text on a near-black background, or the light theme. | Not run |
| Colour alone | Play, record and delete also use text or a symbol. | Review in Interface Builder or on device |
| Touch size | Primary controls request at least 44 by 44 points. | Not measured on device |
| iPad split view, rotation and Stage Manager | iPhone uses a tab bar. iPad regular width opens scripts in `NavigationSplitView`. The recorder switches between a side-by-side and stacked layout. | Not run |
| VoiceOver over a camera preview | The preview has a front or rear camera label. Script text remains readable as an accessibility element. | Not run |

Reading profiles match the reference set: default, dyslexia-friendly, low vision, high contrast, calm focus, caption-first and simple controls. Simple profiles hide the extra prompter sliders and leave play and speed available.
