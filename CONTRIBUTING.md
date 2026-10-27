# Contributing

Thanks for helping! Bug reports, ideas, docs and code are all welcome.

## Ground rules
- Be kind: see the [Code of Conduct](CODE_OF_CONDUCT.md).
- For anything bigger than a small fix, **open an issue first** so we can agree on the approach.
- Core priority: the reading experience (smooth scrolling, readable text) must never regress for optional features.

## Setup
```bash
flutter pub get
flutter analyze        # must be clean
flutter test           # must pass
```
Run on an Android device or emulator (`flutter run`). Camera recording needs a real device.

## Pull requests
1. Fork, then branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Keep the change focused; add or update tests (`test/`) for behaviour changes.
3. Follow the layering: `features/*/presentation → application → domain ← data`; `domain/` must not import Flutter or plugins.
4. Run `dart format .`, `flutter analyze`, `flutter test`.
5. Fill in the PR template. Use clear commit messages (e.g. `fix: camera init after permission grant`).

## Reporting bugs
Use the bug template. Include device model, Android version, app version and steps. For file import problems, attach a sample file if you can share it.

## Releases (maintainers)
Update `version:` in `pubspec.yaml` and `CHANGELOG.md`, then push a tag `vX.Y.Z`. The release workflow builds and attaches the APK.
