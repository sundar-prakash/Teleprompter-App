# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/), versioning follows [SemVer](https://semver.org/).

## [1.0.2] - 2026-11-25

### Fixed
- Floating window no longer gets stuck on "Loading script…": the app now sends the script to the window directly instead of waiting for a reply that the overlay plugin could misroute.
- Floating window opens at its intended size on high-density screens (it opened about a third of the size, squeezing the controls and script).
- Floating window controls are one fixed row (play and close always visible, the rest scrolls), so they never overflow or cover the script; shows a clear message if the script can't load.
- Reading position from the floating window is restored when you return to the app.
- Prompter: controls sit on a solid panel, so the script no longer shows through the progress bar and buttons.
- Import preview: buttons and options no longer overflow on small phones, with large system text or with the keyboard open.
- Editor: long titles get more room on narrow phones (Present becomes an icon button).
- Home: title no longer truncated next to the About button.

## [1.0.1] - 2026-10-27

### Added
- App logo: launcher icon (adaptive), Home screen and README.
- About screen (Home and Settings › ⓘ): version, links to website, privacy policy, terms, source code, open-source licences, developer portfolio and GitHub, rate and share.

### Changed
- Android package name is now `in.sundarprakash.teleprompter` (first Google Play release).
- Pace controls are now explicit **Slower** / **Faster** buttons with the current seconds-per-line between them (previously +/- which moved the number the opposite way to the speed).
- Settings slider shows "faster" and "slower" ends.

## [1.0.0] - 2026-10-27
First public release (Android).

### Added
- Script import: PDF (selectable text), DOCX, SRT, TXT, Markdown, with preview and original-text backup.
- Library, editor with autosave, statistics, export/share.
- Five reading modes (continuous, single line, paragraph, manual, subtitle), pace in seconds per line, auto-pause, countdown.
- Pinch-to-zoom while paused, quick mirror/flip, bookmarks, highlights, display profiles, custom colours.
- Camera mode with six layouts, recording, pause/resume, torch, camera switch, resolution/fps, review, save to gallery.
- System Picture-in-Picture and floating overlay above other apps.
