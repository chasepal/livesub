# Publish to GitHub

This repo is prepared for:

```text
https://github.com/keziqicoze09-del/livesub
```

## 1. Create the GitHub Repository

Open:

```text
https://github.com/new
```

Use:

- Owner: `keziqicoze09-del`
- Repository name: `livesub`
- Description: `Better live Chinese subtitles for anything playing in Chrome.`
- Visibility: public

Do not initialize with README, `.gitignore`, or license. They already exist locally.

## 2. Push Source and Tag

From the repository root:

```sh
git push -u origin main
git push origin v0.2.0-alpha
```

## 3. Create the Release

Open:

```text
https://github.com/keziqicoze09-del/livesub/releases/new
```

Use:

- Tag: `v0.2.0-alpha`
- Title: `LiveSub v0.2.0-alpha`
- Release notes: copy from `docs/github-release-v0.2.0-alpha.md`
- Asset: upload `build/releases/LiveSub-v0.2.0-alpha-macos.zip`

## 4. Verify

After publishing, check:

- README renders correctly.
- Chinese README link works.
- Release asset downloads.
- SHA-256 matches:

```text
d3acc4eddcf6e9b0bd4d3fd4e0c73e561fb583517011d53967fd1d2955e11026
```

## Current Local State

The local repository already has:

- Branch: `main`
- Remote: `origin -> https://github.com/keziqicoze09-del/livesub.git`
- Tag: `v0.2.0-alpha`
- Release zip: `build/releases/LiveSub-v0.2.0-alpha-macos.zip`
