# Teleprompter Pro — Architecture & Roadmap

Status legend: ✅ done · 🚧 in progress · ⬜ pending

## 1. Layering

```
lib/
  core/            theme, breakpoints, logging, result/error types, utils
  domain/          pure Dart: models + repository interfaces + services (no Flutter imports)
  data/            persistence (JSON files + shared_preferences), importers (isolates)
  features/
    home/ library/ editor/ teleprompter/ settings/ camera/ overlay/
      ├─ application/   Riverpod notifiers (business logic)
      └─ presentation/  screens + widgets
  app/             router, shell, shortcuts, bootstrap
```

Rule: `presentation → application → domain ← data`. Domain never imports Flutter or plugins.

State management: **Riverpod** (no codegen; fewer moving parts, testable via overrides).
Navigation: **go_router** with an adaptive shell (bottom bar <600dp, rail 600–1100dp, extended rail/sidebar ≥1100dp).

## 2. Packages (checked against platform targets)

| Package | Purpose | Android | iOS | Win | macOS | Linux |
|---|---|---|---|---|---|---|
| flutter_riverpod | state | ✅ | ✅ | ✅ | ✅ | ✅ |
| go_router | nav | ✅ | ✅ | ✅ | ✅ | ✅ |
| shared_preferences | settings | ✅ | ✅ | ✅ | ✅ | ✅ |
| path_provider / path | storage | ✅ | ✅ | ✅ | ✅ | ✅ |
| file_picker | import/export | ✅ | ✅ | ✅ | ✅ | ✅ |
| archive + xml | .docx parsing (zip + OOXML) | pure Dart |
| pdfrx | PDF text extraction (PDFium, permissive licence) | ✅ | ✅ | ✅ | ✅ | ✅ |
| window_manager | fullscreen, always-on-top, resize | – | – | ✅ | ✅ | ✅ |
| wakelock_plus | keep screen awake while playing | ✅ | ✅ | ✅ | ✅ | ✅ |
| camera (+ camera_desktop / camera_macos, Phase 6) | preview & recording | ✅ | ✅ | ⚠ via community plugins | ⚠ | ⚠ |

Rejected: `syncfusion_flutter_pdf` (commercial licence terms). Legacy binary `.doc` has no pure-Dart parser; see limitations.

## 3. Navigation

`/` Home · `/library` · `/editor/:id` · `/play/:id` (full-screen, no shell) · `/camera/:id` (Phase 6, no shell) · `/settings`.
Teleprompter and camera routes sit outside the shell so chrome never competes with the script.

## 4. Responsive strategy (Material 3 window classes)

| Class | Width | Navigation | Library | Workspace controls |
|---|---|---|---|---|
| compact | <600 | bottom bar | list | bottom sheet, thumb reach |
| medium | 600–1199 | rail | grid 2–3 | docked side panel |
| expanded | ≥1200 | sidebar | grid + detail pane | docked panel + floating option |

Orientation changes are handled by `LayoutBuilder`, never by locking, except the workspace which may be user-locked.

## 5. Data models (domain)

- `Script { id, title, body (edited), originalBody?, sourceFormat, sourceFileName?, srtCues?, createdAt, updatedAt, lastOpenedAt, bookmarks[], highlights[], profileId? }`
- `SrtCue { index, start, end, text }`
- `TeleprompterSettings` — typography, display, colours, mirror/flip, reading area, margins, speed, countdown, start delay, pause intervals, mode, resume behaviour, guide-line.
- `DisplayProfile { id, name, TeleprompterSettings }` (multiple profiles).
- `ShortcutBinding { action, LogicalKeySet }`.
- `PlaybackState { status, offset, speed, elapsed }` — runtime only.

Persistence: one JSON file per script (`scripts/<id>.json`) + lightweight index; settings & profiles in shared_preferences JSON. Original import kept in `originalBody`, never overwritten by edits. Everything has `schemaVersion` for migration.

## 6. Playback engine

Single `Ticker`-driven controller. Position is advanced by `speed(px/s) * dt` from the ticker's elapsed delta (not timers), clamped dt to avoid jumps after frame stalls. Reading is rendered with `ListView.builder` over paragraphs (lazy), with the scroll position driven by `ScrollController.jumpTo` per frame. Mirror/flip via `Transform`. Modes (continuous, single-line, paragraph, manual, subtitle) are strategies over a shared `PlaybackClock`.

## 7. Platform limitations (Sections 7 & 13) — stated honestly

| Capability | Android | iOS | Desktop |
|---|---|---|---|
| Native system PiP | Possible (Activity PiP, API 26+) — needs native Kotlin; PiP shows a *view*, so Flutter content needs a texture/`Presentation` bridge. Phase 7. | Only AVPictureInPictureController for **video/AVSampleBufferDisplayLayer**; arbitrary Flutter UI cannot be PiP'd without rendering the script to a sample-buffer stream. Investigated in Phase 7; may be descoped. | n/a |
| OS-level overlay above other apps | `SYSTEM_ALERT_WINDOW` + foreground service + second FlutterEngine. Phase 7. | **Not permitted.** Alternative: in-app floating panel + (optional) system PiP. | Always-on-top window via window_manager ✅ |
| Camera + recording | `camera` ✅ | `camera` ✅ (no background camera) | Needs community plugins; quality varies |
| External display | Presentation API (native) | UIScreen external scene (native) | Second window; Flutter multi-window still experimental |
| `.doc` (binary Word) | unsupported by pure-Dart parsers → clear error recommending save-as .docx | same | same |
| Scanned PDFs | no OCR bundled; detected and reported with guidance | same | same |

UI will label three tiers distinctly: **Native PiP**, **OS overlay**, **In-app floating panel**. Nothing is simulated and relabelled.

## 8. Roadmap

1. ✅ Phase 0 — scaffold, packages, this document
2. ✅ Phase 1 — domain models, SRT parser, text stats, persistence, settings, theme, adaptive shell, home/library/editor, continuous-scroll workspace (+ 16 unit/widget tests; macOS debug build verified)
3. ⬜ Phase 2 — importers: txt/md/srt/docx/pdf in isolates, preview screen, error mapping
4. ⬜ Phase 3 — remaining modes (single-line, paragraph, subtitle), countdown/auto-pause, bookmarks, highlights
5. ⬜ Phase 4 — desktop: configurable shortcuts, fullscreen, always-on-top, floating controls
6. ⬜ Phase 5 — profiles, custom themes, export
7. ⬜ Phase 6 — camera mode: preview, layouts, recording, sync
8. ⬜ Phase 7 — Android PiP/overlay (native), iOS PiP investigation, external display
9. ⬜ Phase 8 — integration tests, perf profiling, QA record

## 9. Status record (v1.0.0, Android)

**Scope:** Android only (API 24+). iOS and desktop code from the Flutter template is present but unsupported and untested.

**Implemented:** adaptive shell; Home, Library, Editor, Settings; importers (PDF text, DOCX, SRT, TXT, MD) in background isolates with preview and original-text backup; five reading modes (continuous, single line, paragraph, manual, subtitle); pace in seconds per line; auto-pause; countdown; pinch-to-zoom while paused; quick mirror/flip; bookmarks and highlights; display profiles; custom colours; export; camera mode (six layouts, recording, pause/resume, torch, camera switch, resolution/fps with automatic step-down, review, save to gallery); native Android Picture-in-Picture with remote actions; floating overlay (SYSTEM_ALERT_WINDOW + foreground service) with ready/init handshake.

**Distinct by design:** PiP = the app itself shrunk by Android; Overlay = a separate Flutter engine drawn above other apps; in-app floating script box = camera layout 6.

**Verified:** `flutter analyze` (no errors/warnings), 30 unit/widget tests, debug app launched on an Android 13 emulator. **Not verified on a physical device:** camera recording, PiP, overlay, large-PDF performance.

**Known limits:**
- Scanned PDFs (no OCR) and legacy `.doc` are rejected with guidance.
- Bookmarks/highlights are stored by paragraph index and can shift when paragraphs are added or removed.
- PiP windows cannot be transparent on Android; opacity applies to the overlay only.
- Camera plugin cannot enumerate supported resolutions; the app tries the chosen one and steps down.
- Release builds use the debug key unless `android/key.properties` is provided.
