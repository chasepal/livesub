# Roadmap

LiveSub is currently an alpha macOS app focused on low-latency Chinese subtitles for Chrome audio.

## v0.2.0-alpha

Goal: make the project understandable and usable from GitHub.

- Public app name: LiveSub
- Bundle ID: `app.livesub.mac`
- Release build artifact: `LiveSub-v0.2.0-alpha-macos.zip`
- Default subtitle mode: text-only overlay
- Default placement: bottom-centered subtitle overlay
- Chrome app-level audio capture
- Cloud AST mode with user-provided Volcengine/Doubao Speech API Key
- Local mode with WhisperKit + Ollama
- Root README, Chinese README, privacy note, and roadmap

## v0.3-alpha

Goal: make the daily subtitle experience feel polished.

- Better first-run onboarding
- Clear permission diagnostics
- Better API Key validation and error messages
- Small floating control dot as a complete daily control entry
- Keyboard shortcuts
- Lock / do-not-block-mouse subtitle behavior
- Better subtitle style presets
- Screenshot/GIF assets for GitHub

## v0.4-alpha

Goal: go beyond subtitles into live understanding.

- "What did I miss?" summary for the last few minutes
- Keyword highlighting
- User glossary / hot words
- Entity extraction for people, products, projects, tickers, and topics
- Session recap as Markdown
- Copy/share selected transcript blocks

## v0.5-beta

Goal: make public distribution smoother.

- Signed and notarized build, if Apple Developer ID is available
- DMG packaging
- Homebrew Cask
- Auto-update exploration
- Cleaner internal package names
- Better test coverage around UI preferences and session persistence

## Not Yet

These are intentionally out of scope for the first public alpha:

- Full meeting assistant workflow
- Team collaboration
- Cloud transcript storage
- Browser extension
- Tab-level Chrome capture
- Windows/Linux support
