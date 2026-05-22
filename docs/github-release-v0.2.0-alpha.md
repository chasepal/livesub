# LiveSub v0.2.0-alpha

First public alpha for LiveSub.

LiveSub is a native macOS app that captures Google Chrome audio and shows low-latency Chinese subtitles in a floating overlay. It is designed for English live streams, YouTube, Twitch, X Spaces in Chrome, podcasts, interviews, courses, launches, and other English audio playing in Chrome.

## Download

Download:

```text
LiveSub-v0.2.0-alpha-macos.zip
```

Unzip it, then right-click `LiveSub.app` and choose **Open**. This alpha build is ad-hoc signed and not notarized, so macOS may show an unidentified-developer warning.

## Highlights

- Public app name changed to `LiveSub`
- Bundle ID changed to `app.livesub.mac`
- Default subtitle mode is a text-only overlay
- Default subtitle placement is bottom-centered
- Cloud AST mode for lower local CPU/GPU usage
- Local mode with WhisperKit + Ollama remains available
- Subtitle sessions are saved locally
- English README, Chinese README, privacy note, roadmap, and MIT license added

## Known Limitations

- Not notarized yet
- Chrome capture is app-level, not tab-level
- First-run onboarding is still basic
- Screenshots and demo GIF are not included yet
- Cloud mode requires your own Volcengine/Doubao Speech API Key

## SHA-256

```text
d3acc4eddcf6e9b0bd4d3fd4e0c73e561fb583517011d53967fd1d2955e11026  LiveSub-v0.2.0-alpha-macos.zip
```
