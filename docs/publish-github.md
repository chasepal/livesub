# Publish to GitHub

This repo is prepared for:

```text
https://github.com/chasepal/livesub
```

## 1. Create the GitHub Repository

Open:

```text
https://github.com/new
```

Use:

- Owner: `chasepal`
- Repository name: `livesub`
- Description: `Better live Chinese subtitles for anything playing in Chrome.`
- Visibility: public

Do not initialize with README, `.gitignore`, or license. They already exist locally.

## 2. Push Source and Tag

From the repository root:

```sh
git push -u origin main
git push origin v0.2.1-alpha
```

## 3. Create the Release

Open:

```text
https://github.com/chasepal/livesub/releases/new
```

Use:

- Tag: `v0.2.1-alpha`
- Title: `LiveSub v0.2.1-alpha`
- Release notes: copy from `docs/github-release-v0.2.1-alpha.md`
- Asset: upload `build/releases/LiveSub-v0.2.1-alpha-macos.zip`

## 4. Verify

After publishing, check:

- README renders correctly.
- Chinese README link works.
- Release asset downloads.
- SHA-256 matches:

```text
bfe5facc2ad961e784de818a7fb390df65495a0dc07d4aa726fe919d5057226d
```

## Current Local State

The local repository already has:

- Branch: `main`
- Remote: `origin -> https://github.com/chasepal/livesub.git`
- Tag: `v0.2.1-alpha`
- Release zip: `build/releases/LiveSub-v0.2.1-alpha-macos.zip`
