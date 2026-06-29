# LiveSub v0.2.1-alpha

Subtitle polish update for LiveSub.

LiveSub is a native macOS app that captures Google Chrome audio and shows low-latency Chinese subtitles in a floating overlay. This update focuses on making the daily subtitle window feel cleaner and easier to follow during live streams.

## Download

Download:

```text
LiveSub-v0.2.1-alpha-macos.zip
```

Unzip it, then right-click `LiveSub.app` and choose **Open**. This alpha build is ad-hoc signed and not notarized, so macOS may show an unidentified-developer warning.

## Changes

- Improved text-only subtitle rendering by removing the heavy black stroke.
- Kept the text-only overlay transparent while retaining a subtle readability shadow.
- Increased text-only overlay capacity so more context can stay visible.
- Fixed the history panel so it follows the newest subtitle automatically.
- Build script now creates both `/Applications/LiveSub.app` and a versioned `/Applications/LiveSub-0.2.1-alpha.app`.
- README and build paths now point to `v0.2.1-alpha`.

## Known Limitations

- Not notarized yet.
- Chrome capture is app-level, not tab-level.
- First-run onboarding is still basic.
- Cloud mode requires your own Volcengine/Doubao Speech API Key. Setup guide: `docs/volcengine-doubao-api-key.md`.

## SHA-256

```text
bfe5facc2ad961e784de818a7fb390df65495a0dc07d4aa726fe919d5057226d  LiveSub-v0.2.1-alpha-macos.zip
```
