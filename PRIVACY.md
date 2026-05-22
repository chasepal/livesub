# Privacy

LiveSub is designed as a local-first macOS utility. It does not include analytics, telemetry, ads, accounts, or background upload jobs.

## What LiveSub Captures

LiveSub uses macOS ScreenCaptureKit to select Google Chrome and capture Chrome app audio. It does not capture your microphone. It does not intentionally capture other apps.

Current alpha limitation: capture is app-level for Chrome, not tab-level. If multiple Chrome tabs are playing audio, LiveSub may receive Chrome audio from all of them.

## Cloud Mode

Cloud AST mode streams short Chrome audio chunks to Volcengine/Doubao Speech over WebSocket for speech recognition and translation.

Use cloud mode when you want:

- Lower local CPU/GPU usage
- Less fan noise
- Better long-session usability on smaller Macs

Your Volcengine account controls billing, quotas, logs, and data handling on the provider side. Review Volcengine's own service terms and privacy policy before using cloud mode with sensitive audio.

## Local Mode

Local mode keeps transcription and translation on your Mac. It uses WhisperKit for ASR and Ollama/Qwen for translation.

Use local mode when you want:

- No cloud transcription provider in the loop
- More privacy for sensitive sessions
- Offline or local-network operation

Local mode can use substantially more CPU/GPU/memory.

## Credentials

Volcengine credentials are stored locally at:

```text
~/Library/Application Support/LiveSub/cloud-credentials.json
```

The file is written with user-only permissions. LiveSub does not store API keys in transcript files or UserDefaults.

## Transcript Storage

Subtitle sessions are stored locally at:

```text
~/Library/Application Support/LiveSub/Sessions/
```

Session output may include recognized source text, translated subtitles, timestamps, engine metadata, and session manifests.

## No Telemetry

LiveSub does not currently collect:

- Usage analytics
- Crash reports
- User identifiers
- Browsing history
- Transcript content for project analytics

## Removing Local Data

Quit LiveSub, then remove:

```text
~/Library/Application Support/LiveSub/
```

macOS privacy permissions are managed separately in System Settings.
