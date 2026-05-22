# LiveSub macOS

This folder contains the native macOS implementation.

Current packages:

- `Packages/LocalVCore`: data models, transcript persistence, glossary handling, audio buffering, VAD, and speech window segmentation.
- `Packages/LocalVCaptureProbe`: command-line ScreenCaptureKit probe for Chrome app-level audio.
- `Packages/LocalVAppShell`: native AppKit app bundle used for the current development app.

Build the release app from the repository root:

```sh
./scripts/build-localv-app-shell.sh
```

Open:

```sh
open build/LiveSub.app
```

LiveSub captures Google Chrome app-level audio, offers cloud and local translation engines, shows a floating Chinese subtitle overlay, displays low/medium/high CPU and memory load, and writes subtitle sessions automatically under:

```text
~/Library/Application Support/LiveSub/Sessions/
```

Cloud AST credentials are entered through the cloud configuration dialog and stored locally at:

```text
~/Library/Application Support/LiveSub/cloud-credentials.json
```

Use the Volcengine/Doubao Speech API Key from the speech console API Key management page. Do not use Ark model keys, IAM AccessKey ID, Secret Access Key, or generic OpenAPI credentials for AST mode.

If capture is denied, allow `LiveSub` in System Settings -> Privacy & Security -> Screen & System Audio Recording, then restart the app.
