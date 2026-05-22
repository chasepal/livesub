# LiveSub App Shell

Native AppKit shell for LiveSub. It captures Google Chrome app-level audio with ScreenCaptureKit and shows low-latency Chinese subtitles in a floating overlay.

Current pipeline:

```text
Cloud mode:
ScreenCaptureKit Chrome audio -> Volcengine/Doubao AST WebSocket -> UI + transcript files

Local mode:
ScreenCaptureKit Chrome audio -> VAD speech windows -> WhisperKit ASR -> Ollama Qwen translation -> UI + transcript files
```

Build package:

```sh
swift build -c release
```

Build an app bundle and release zip from the repository root:

```sh
./scripts/build-localv-app-shell.sh
```

Then open:

```sh
open build/LiveSub.app
```

If macOS blocks capture, allow LiveSub in System Settings -> Privacy & Security -> Screen & System Audio Recording.

For Cloud AST mode, paste the Volcengine/Doubao Speech API Key from the speech console API Key management page. New speech-console APIs use `X-Api-Key`. The older access-token fields are only kept for older speech-console compatibility.

Do not use the Ark large-model API Key, IAM AccessKey ID, or Secret Access Key for AST mode. Credentials are stored locally at `~/Library/Application Support/LiveSub/cloud-credentials.json` with user-only file permissions.

Subtitle sessions are written automatically to `~/Library/Application Support/LiveSub/Sessions/` as Markdown, JSONL, and a manifest file.
