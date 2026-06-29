# LiveSub

[中文](./README.zh-CN.md)

Better live Chinese subtitles for anything playing in Chrome.

LiveSub is a native macOS app that captures Google Chrome audio and shows low-latency Chinese subtitles in a floating overlay. It is built for YouTube Live, Twitch, X Spaces in Chrome, podcasts, interviews, courses, launches, and any English audio you want to understand in real time.

> Status: `v0.2.1-alpha`. LiveSub is usable, but still early. Expect rough edges.

## Why LiveSub?

Native captions are useful when you only need same-language captions. LiveSub is for people who need more:

- Chinese translation, not just English captions
- A cleaner subtitle overlay for long live streams
- Subtitle history when you miss a sentence
- Chrome-focused workflow for YouTube, Twitch, X Spaces, courses, interviews, and launches
- Cloud mode for lower local CPU/GPU usage

## Features

- Captures Google Chrome app audio with macOS ScreenCaptureKit
- Shows real-time Chinese subtitles in a floating always-on-top overlay
- Defaults to a text-only subtitle mode that looks closer to native video captions
- Switches to a history panel when you need more context
- Supports Cloud AST mode with Volcengine/Doubao Speech API Key
- Includes a local mode using WhisperKit ASR and Ollama Qwen translation
- Persists subtitle sessions locally as Markdown, JSONL, and manifest files
- Shows low/medium/high CPU and memory load in the control center

## Download

Download the latest alpha build from GitHub Releases:

```text
LiveSub-v0.2.1-alpha-macos.zip
```

Unzip it, then right-click `LiveSub.app` and choose **Open**. The app is currently ad-hoc signed for alpha testing, so macOS may warn that it is from an unidentified developer.

## Quick Start

1. Open `LiveSub.app`.
2. In **Engine & Account**, configure your Volcengine/Doubao Speech API Key. Need help getting one? See [Volcengine/Doubao Speech API Key](./docs/volcengine-doubao-api-key.md).
3. Click **Test Connection**.
4. Grant macOS **Screen & System Audio Recording** permission when prompted.
5. Play English audio in Google Chrome.
6. Click **Start Chrome Subtitles**.

Cloud mode is recommended for most users because it keeps local CPU/GPU usage lower.

## Volcengine API Key

LiveSub Cloud AST mode uses the Speech large-model API Key from Volcengine/Doubao Speech.

Use:

- Speech service API Key from the speech console API Key management page
- Streaming speech recognition / speech translation service enabled

Do not use:

- Ark large-model API Key
- IAM AccessKey ID
- IAM Secret Access Key
- Generic ECS/OpenAPI credentials

LiveSub sends the new speech-console API Key through `X-Api-Key`. The older access-token fields are only kept for compatibility with older speech-console setups.

Step-by-step setup: [Volcengine/Doubao Speech API Key](./docs/volcengine-doubao-api-key.md).

## Privacy

LiveSub does not include telemetry. Cloud mode sends captured Chrome audio chunks to Volcengine/Doubao Speech for recognition and translation. Local mode keeps recognition and translation on your Mac, but uses more local resources.

Read [PRIVACY.md](./PRIVACY.md) for details.

## Local Data

LiveSub stores credentials and transcript sessions under:

```text
~/Library/Application Support/LiveSub/
```

Subtitle sessions are stored under:

```text
~/Library/Application Support/LiveSub/Sessions/
```

## Build From Source

Requirements:

- macOS 15+
- Xcode Command Line Tools
- Swift 6 toolchain

Build the release app bundle and zip:

```sh
./scripts/build-localv-app-shell.sh
```

Outputs:

```text
build/LiveSub.app
build/apps/LiveSub-0.2.1-alpha.app
build/releases/LiveSub-v0.2.1-alpha-macos.zip
```

Run core smoke tests:

```sh
swift run --package-path mac/Packages/LocalVCore LocalVCoreSmokeTests
```

## Roadmap

See [ROADMAP.md](./ROADMAP.md).

## License

MIT. See [LICENSE](./LICENSE).
