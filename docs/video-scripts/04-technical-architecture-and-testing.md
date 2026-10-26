# Presenter 4 — Technical: architecture and reliability

**Your job:** explain the tools, offline design, and verification, then close.
**Your slot:** 2:04–2:44, maximum 40 seconds.

## Read aloud

> Hi, I'm [Name]. The app uses Flutter and Dart, with Swift for iPhone features.
> Profiles and journals use local storage, so they remain available offline.
> New barcode lookups need a connection; previously cached products can be
> checked offline.
>
> Failed saves show a retry warning. Emergency voice pauses while the app is
> locked. The latest checks passed 237 automated tests and an unsigned iOS
> release build.
>
> My contribution was [your actual contribution in 8–12 words]. Claude Code
> and Codex assisted development; our submission documents that assistance.

## Match the screen to your words

| Approximate time within your clip | Show |
|---|---|
| 0–7 seconds | Your face/name, then a simple Flutter/Dart + Swift caption over the real app |
| 7–20 seconds | With airplane mode already on, reopen the saved demo trip and show its journal; then show a previously cached barcode result if available |
| 20–27 seconds | Caption: “Save failures → warning + retry”; demonstrate the lock and return to the app after unlocking |
| 27–33 seconds | A readable screenshot of the actual test result and successful build result, labeled “Development checks” |
| 33–40 seconds | Your contribution sentence and AI acknowledgment over the app, then transition to the credits card |

Do not damage the device's database to create a retry warning for the video. A
caption explaining the implemented behavior is enough. The lock shot demonstrates
the lock; it does not by itself prove microphone behavior. The regression test
covers stopping recognition and discarding speech while locked.

The 237-test count and successful build reflect the verified development run
before these scripts were written. Ask the teammate with the Mac for real check
output or rerun the checks if the app changes. An unsigned build demonstrates
compilation, not successful installation, distribution, or medical validation.
If a cached barcode result is not prepared, show only the offline journal and
leave the cache explanation as narration.

## Prepare to explain

- **Flutter/Dart:** the app's interface and most application logic.
- **Swift bridges:** connect Dart to iPhone capabilities such as on-device speech
  and Apple's optional on-device language model.
- **SQLite:** keeps structured records on this device. Preferences keep settings.
- **Offline limits:** new database lookups and first-time translation-pack
  downloads need connectivity. Photos and translated text are processed locally;
  ML Kit still sends diagnostic data to Google. Do not claim nothing ever leaves
  the phone.
- **Retry queue:** failed writes stay pending in order while the app is open.
  Closing the app before recovery can lose those pending changes.
- **AI assistance:** explain its actual scope, and distinguish generated work
  from the students' own work. Finish the full disclosure before recording the
  closing sentence; a short video credit does not replace it.

Code to understand: `lib/services/database.dart`, `lib/services/app_state.dart`,
`ios/Runner/SpeechBridge.swift`, and `test/submission_readiness_test.dart`.

**Deliver:** `04-name-narration.mp4`, `04-name-screen.mp4`, and your name/contribution text.
