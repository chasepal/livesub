# LiveSub Architecture

LiveSub is a native macOS app built around one workflow:

```text
Google Chrome audio -> speech recognition / translation -> floating Chinese subtitles -> local session files
```

## Packages

- `mac/Packages/LocalVAppShell`: current AppKit app shell. Public app name is LiveSub; internal SwiftPM target names still use the original development names.
- `mac/Packages/LocalVCore`: shared subtitle/session/audio primitives.
- `mac/Packages/LocalVCaptureProbe`: command-line ScreenCaptureKit probe used during development.

## Capture

LiveSub uses ScreenCaptureKit to select Google Chrome as the captured application. Capture is currently Chrome app-level, not tab-level.

The stream configuration uses low-resolution video settings and focuses on audio:

- Audio capture enabled
- Cursor hidden
- 16 kHz mono audio for the speech pipeline
- Current process audio excluded

## Cloud Mode

Cloud mode is the recommended default for public alpha users.

```text
Chrome audio -> AudioProbe -> Volcengine/Doubao AST WebSocket -> subtitle UI -> transcript persistence
```

Why cloud mode first:

- Lower local CPU/GPU usage
- Better fan/noise behavior on everyday Macs
- Faster path to usable long live-stream sessions

## Local Mode

Local mode is available for users who prefer local inference.

```text
Chrome audio -> VAD speech windows -> WhisperKit ASR -> Ollama Qwen translation -> subtitle UI -> transcript persistence
```

Tradeoff:

- Better privacy
- More local resource usage
- More setup complexity

## UI

LiveSub has two subtitle surfaces:

- Text-only overlay: default mode, bottom-centered, closer to native video captions.
- History panel: multi-line subtitle history for context and recovery.

The main window is a control center for capture, engine setup, subtitle appearance, diagnostics, and saved sessions.

## Local Storage

LiveSub stores local data under:

```text
~/Library/Application Support/LiveSub/
```

Important files:

- `cloud-credentials.json`: Volcengine/Doubao Speech credentials
- `Sessions/`: Markdown, JSONL, and manifest files for subtitle sessions

## Build

The release packaging script is:

```sh
./scripts/build-localv-app-shell.sh
```

It produces:

```text
build/LiveSub.app
build/apps/LiveSub-0.2.1-alpha.app
build/releases/LiveSub-v0.2.1-alpha-macos.zip
```
