# Version 1.1.1 validation

- Fixed the missing-key loop that reopened Settings immediately after Done.
- Settings now uses a standard Mac window with a close button; Escape and Done both close it.
- The offscreen regression test passed for missing Fish credentials, paused hands-free mode, native Escape handling, and a closable window.
- Added a native drag surface to the panel's bezel and background. Actual control bounds are excluded so buttons keep receiving clicks. Drag hit-testing passed with offset view coordinates.
- P3 was exercised in the live app after adding the drag surface. The computer-control helper stopped while inspecting the settings sheet, so final pointer-drag and close-button interactions could not be completed through that helper. The rebuilt app passes strict code-signature verification. Quit and reopen KITT to load the final standard Settings window.

## Earlier version 1.1 checks

- Native Apple Silicon app compiled successfully and passed strict local code-signature verification.
- Automatic turn detection passed tests for an empty room, ongoing microphone speech, new words extending a turn, duplicate partial transcripts, steady background noise, and configurable reply pauses.
- Actual Kokoro speech audio passed the LED-envelope checks: outside stacks have identical values, the middle stack is taller, and all LEDs return to silence after playback.
- The compact SwiftUI view rendered successfully at 768 × 886 pixels and was visually inspected against the supplied voice-box screenshot. `compact-preview.png` is an offscreen preview of the app's own view.
- The updated app process started and consumed the temporary conversation handoff. The current conversation was carried across the update.
- Live screen/microphone validation could not be completed because the Codex computer-control helper stopped during the relaunch. The app itself remained running. On-device microphone permission and the complete live listen/reply/listen cycle should be confirmed by speaking to the updated app.

The app's microphone pauses while generating/playing a reply or showing settings. AIR pauses/resumes hands-free listening; P2 stops the current activity and pauses listening. Fish voice configuration and the free-model restriction are unchanged.
