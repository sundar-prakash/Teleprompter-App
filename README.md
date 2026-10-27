# Teleprompter

**A free, open-source teleprompter for Android.** Import a script, read it in the pace you choose, record yourself with the front camera while reading, or keep the script floating over another app.

> Platform: **Android 7.0+ (API 24)**. iOS and desktop are not supported yet (see [Roadmap](#roadmap)).
> Privacy: no account, no analytics, no network access. Scripts and recordings stay on your device.

## Features

**Scripts**
- Import `.pdf` (selectable text), `.docx`, `.srt`, `.txt`, `.md` from device storage or cloud providers (Google Drive etc., through Android's file picker).
- Preview before saving; the original import is kept separately so you can restore it after editing.
- Library with search, sort, list/grid, rename, duplicate, delete; export via the share sheet.
- Word/character counts and estimated reading time.
- SRT: keep subtitle timing (enables Subtitle mode) or convert to a continuous script.

**Reading**
- Five modes: **Continuous**, **Single line** (one line at a time), **Paragraph** (with hold time), **Manual**, **Subtitle** (SRT timestamps).
- Pace is set in **seconds per line**, independent of font size. Optional auto-pause every N seconds.
- Pinch to zoom the text while paused. Mirror and vertical-flip buttons right in the prompter.
- Typography, colours, margins, reading width, reading line, RTL, countdown, bookmarks, highlights, saved display profiles.

**Recording and multitasking**
- **Camera mode**: live front-camera preview with six script layouts, countdown, record/pause/resume, torch, camera switch, resolution and frame-rate choice, preview, save to gallery or share.
- **Picture-in-picture**: Android system PiP with play/pause/speed buttons.
- **Float over other apps**: a movable, resizable, semi-transparent script window above other apps (needs the "Display over other apps" permission).

## Permissions

Each permission is requested only when you use the feature, after an explanation.

| Permission | Used for |
|---|---|
| Camera, Microphone | Camera mode |
| Display over other apps | Float over other apps |
| Notifications | Status notification while the floating script runs |

## Install

Download the APK from the [Releases](../../releases) page and open it on your phone (allow "install unknown apps" for your browser/file manager when asked).

## Build from source

Requirements: Flutter (stable, Dart 3.13+), Android SDK 37.

```bash
git clone https://github.com/<your-username>/teleprompter.git
cd teleprompter
flutter pub get
flutter run                                   # debug on a connected device/emulator
flutter build apk --release --target-platform android-arm64
```

Optional release signing: copy `android/key.properties.example` to `android/key.properties` and fill it in.

## Project layout

```
lib/
  domain/     pure Dart: models, SRT parser, text stats, repository interfaces
  data/       file storage, settings store, document importers
  features/   home, library, editor, import, teleprompter, camera, overlay, settings
  platform/   Android integrations: PiP, overlay, permissions, export
  app/        router, shell, providers
```
More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Roadmap

- iOS (system PiP only; iOS does not allow app-wide overlays)
- Desktop (shortcuts, always-on-top window)
- OCR for scanned PDFs, legacy `.doc`
- Voice-assisted scrolling, remote control, optional sync

Ideas and bugs: please open an [issue](../../issues). Contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
