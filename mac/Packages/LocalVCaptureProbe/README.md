# LocalVCaptureProbe

Small command-line probe for validating the v1 audio capture path before the full Xcode app exists.

It uses ScreenCaptureKit to:

- list shareable applications,
- select Google Chrome by bundle id,
- build an app-level content filter,
- capture audio sample buffers for a short duration.

Usage:

```sh
swift run LocalVCaptureProbe --list
swift run LocalVCaptureProbe --duration 10
swift run LocalVCaptureProbe --bundle-id com.google.Chrome --duration 10
```

This may require macOS Screen Recording permission. The final app will include a proper permission guide.

