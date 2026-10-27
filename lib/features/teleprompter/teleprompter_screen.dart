import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../core/log.dart';
import '../../domain/models/script.dart';
import '../../domain/models/teleprompter_settings.dart';
import '../../platform/export.dart';
import '../../platform/overlay_service.dart';
import '../../platform/permissions.dart';
import '../../platform/pip_service.dart';
import '../settings/teleprompter_settings_panel.dart';
import 'pinch_zoom.dart';
import 'playback_controller.dart';
import 'script_view.dart';
import 'workspace_controls.dart';

class TeleprompterScreen extends ConsumerStatefulWidget {
  const TeleprompterScreen({super.key, required this.scriptId});
  final String scriptId;

  @override
  ConsumerState<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends ConsumerState<TeleprompterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PlaybackController _pc;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _focus = FocusNode();
  bool _controlsVisible = true;
  Timer? _hideTimer;
  StreamSubscription<String>? _pipSub;
  bool _warnedNoCues = false;
  double _pinchBaseSize = 44;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = ref.read(settingsProvider);
    _pc = PlaybackController(
      vsync: this,
      speed: s.pixelsPerSecond,
      countdownSeconds: s.countdownSeconds,
    )..addListener(_onPlayback);
    _applySettings(s);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(scriptsProvider.notifier).markOpened(widget.scriptId);
    });
    try {
      WakelockPlus.enable();
    } catch (e, st) {
      logError('wakelock', e, st);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pipSub = PipService.actions.listen((a) {
      switch (a) {
        case 'play':
          _pc.play();
        case 'pause':
          _pc.pause();
        case 'slower':
          _adjustSpeed(faster: false);
        case 'faster':
          _adjustSpeed(faster: true);
      }
    });
    PipService.inPip.addListener(_onPipChanged);
  }

  List<String>? _paras;
  String? _parasFor;
  List<String> _paragraphs(String body) {
    if (_parasFor != body) {
      _paras = paragraphsFor(body);
      _parasFor = body;
    }
    return _paras!;
  }

  /// Subtitle mode needs cues; otherwise fall back to continuous.
  TeleprompterSettings _effective(TeleprompterSettings s) {
    final script = ref.read(scriptByIdProvider(widget.scriptId));
    if (s.mode == ReadingMode.subtitle && (script?.cues.isEmpty ?? true)) {
      return s.copyWith(mode: ReadingMode.continuous);
    }
    return s;
  }

  void _applySettings(TeleprompterSettings s) {
    final script = ref.read(scriptByIdProvider(widget.scriptId));
    var eff = _effective(s);
    if (PipService.inPip.value) {
      eff = eff.copyWith(fontSize: eff.fontSize * s.pipFontScale);
    }
    _pc.configure(eff, cues: script?.cues ?? const []);
    if (s.mode == ReadingMode.subtitle &&
        eff.mode != ReadingMode.subtitle &&
        !_warnedNoCues) {
      _warnedNoCues = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Subtitle mode needs a script imported from an SRT file with timing kept.',
            ),
          ),
        );
      });
    }
  }

  PlaybackStatus? _lastStatus;
  void _onPlayback() {
    if (_pc.status == _lastStatus) return;
    _lastStatus = _pc.status;
    final s = ref.read(settingsProvider);
    PipService.configure(
      autoEnter: s.autoPip && _pc.isPlaying,
      playing: _pc.isPlaying,
      portrait: s.pipPortrait,
    );
    if (_pc.status == PlaybackStatus.playing) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
      if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
    }
  }

  void _onPipChanged() {
    if (!mounted) return;
    _applySettings(ref.read(settingsProvider));
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restore position made in the floating overlay, if any.
      final p = OverlayService.takeProgress(widget.scriptId);
      if (p != null) _pc.seek(p);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!ref.read(settingsProvider).autoHideControls) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _pc.status == PlaybackStatus.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    if (_pc.status == PlaybackStatus.playing) _scheduleHide();
  }

  void _exit() {
    if (mounted) context.pop();
  }

  void _adjustSpeed({required bool faster}) => ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(
          secondsPerLine: TeleprompterSettings.nudgeSeconds(
            s.secondsPerLine,
            faster: faster,
          ),
        ),
      );

  void _adjustSize(double d) => ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(fontSize: (s.fontSize + d).clamp(16, 140).toDouble()),
      );

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---- menu actions -------------------------------------------------------

  Future<void> _onMenu(String v, Script script) async {
    switch (v) {
      case 'pip':
        if (!await PipService.isSupported()) {
          _snack('Picture-in-picture is not available on this device.');
          return;
        }
        final s = ref.read(settingsProvider);
        final ok = await PipService.enter(
          playing: _pc.isPlaying,
          portrait: s.pipPortrait,
        );
        if (!ok) _snack('Could not enter picture-in-picture.');
      case 'overlay':
        await _toggleOverlay(script);
      case 'camera':
        _pc.pause();
        context.push('/camera/${script.id}');
      case 'export':
        try {
          await exportScript(script);
        } catch (e, st) {
          logError('export', e, st);
          _snack('Could not export the script.');
        }
      case 'edit':
        _pc.pause();
        context.push('/editor/${script.id}');
    }
  }

  Future<void> _toggleOverlay(Script script) async {
    if (await OverlayService.isActive()) {
      await OverlayService.close();
      return;
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Float script over other apps'),
        content: const Text(
          'Shows your script in a small window that stays on top of other apps, so you can read it while '
          'using your phone\'s own camera app or a video-call app.\n\n'
          'You can drag it, resize it, change its opacity, lock it in place, or shrink it to a small bubble. '
          'The app will go to the background so you can open the other app.\n\n'
          'This is different from Picture-in-picture, which shrinks this app itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (!await ensureOverlayPermission(context)) {
      if (mounted) {
        _snack(
          'Floating script needs the "Display over other apps" permission.',
        );
      }
      return;
    }
    if (!mounted) return;
    await requestNotificationPermissionIfNeeded(context);
    _pc.pause();
    await OverlayService.show(
      scriptId: script.id,
      text: script.body,
      settings: ref.read(settingsProvider),
      progress: _pc.progress,
    );
    // Go to the background so the floating script appears over whatever is next.
    await PipService.minimize();
  }

  void _showBookmarks(Script script) {
    final paras = _paragraphs(script.body);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final live = ref.watch(scriptByIdProvider(script.id)) ?? script;
          final cur = _pc.currentParagraph;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(
                    live.bookmarks.contains(cur)
                        ? Icons.bookmark_remove
                        : Icons.bookmark_add,
                  ),
                  title: Text(
                    live.bookmarks.contains(cur)
                        ? 'Remove bookmark here'
                        : 'Bookmark current paragraph',
                  ),
                  onTap: () => ref
                      .read(scriptsProvider.notifier)
                      .toggleBookmark(script.id, cur),
                ),
                const Divider(),
                if (live.bookmarks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No bookmarks yet. Long-press a paragraph to highlight it.',
                    ),
                  ),
                for (final b in live.bookmarks.where((b) => b < paras.length))
                  ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(
                      paras[b],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pc.scrollToParagraph(b);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.inPip.removeListener(_onPipChanged);
    PipService.configure(autoEnter: false, playing: false, portrait: false);
    _pipSub?.cancel();
    _hideTimer?.cancel();
    _pc
      ..removeListener(_onPlayback)
      ..dispose();
    _focus.dispose();
    try {
      WakelockPlus.disable();
    } catch (e, st) {
      logError('wakelock', e, st);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(scriptByIdProvider(widget.scriptId));
    final s = ref.watch(settingsProvider);
    ref.listen(settingsProvider, (_, n) => _applySettings(n));

    if (script == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This script no longer exists.')),
      );
    }
    final inPip = PipService.inPip.value;
    final eff = _effective(s);
    final shown = inPip
        ? eff.copyWith(fontSize: eff.fontSize * s.pipFontScale)
        : eff;
    final paragraphs = _paragraphs(script.body);
    final isSubtitle = eff.mode == ReadingMode.subtitle;

    final content = isSubtitle
        ? ListenableBuilder(
            listenable: _pc,
            builder: (_, _) =>
                SubtitleView(cue: _pc.currentCue, settings: shown),
          )
        : ScriptView(
            paragraphs: paragraphs,
            settings: shown,
            playback: _pc,
            highlights: script.highlights.toSet(),
            bookmarks: script.bookmarks.toSet(),
            onParagraphLongPress: inPip
                ? null
                : (i) {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(scriptsProvider.notifier)
                        .toggleHighlight(script.id, i);
                  },
          );

    if (inPip) {
      return Scaffold(backgroundColor: Color(s.backgroundColor), body: content);
    }

    final px = s.fontSize * s.lineHeight * 4;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _pc.toggle,
        const SingleActivator(LogicalKeyboardKey.escape): _exit,
        const SingleActivator(LogicalKeyboardKey.home): _pc.restart,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _adjustSpeed(faster: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _adjustSpeed(faster: false),
        // Bluetooth page-turner / presentation clickers send these keys.
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _pc.jump(-1, px),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _pc.jump(1, px),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _pc.jump(-1, px),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _pc.jump(1, px),
        const SingleActivator(LogicalKeyboardKey.equal): () => _adjustSize(4),
        const SingleActivator(LogicalKeyboardKey.minus): () => _adjustSize(-4),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          key: _scaffold,
          backgroundColor: Color(s.backgroundColor),
          endDrawer: Drawer(
            width: 380,
            child: SafeArea(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Display & playback'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _scaffold.currentState?.closeEndDrawer(),
                    ),
                  ),
                  const Divider(),
                  const Expanded(child: TeleprompterSettingsPanel()),
                ],
              ),
            ),
          ),
          onEndDrawerChanged: (open) {
            if (!open) _focus.requestFocus();
          },
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_controlsVisible && _pc.status == PlaybackStatus.playing) {
                setState(() => _controlsVisible = false);
              } else {
                _showControls();
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  // Pinch to zoom the text while paused/stopped.
                  child: PinchZoom(
                    enabled: !_pc.isPlaying,
                    onStart: () {
                      _pinchBaseSize = ref.read(settingsProvider).fontSize;
                      _showControls();
                    },
                    onScale: (f) => ref
                        .read(settingsProvider.notifier)
                        .update(
                          (x) => x.copyWith(
                            fontSize: (_pinchBaseSize * f)
                                .clamp(16, 140)
                                .toDouble(),
                          ),
                          persist: false,
                        ),
                    onEnd: () => ref.read(settingsProvider.notifier).persist(),
                    child: content,
                  ),
                ),
                Positioned.fill(child: _CountdownOverlay(pc: _pc)),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _controlsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: WorkspaceControls(
                      pc: _pc,
                      title: script.title,
                      hasCues: script.cues.isNotEmpty,
                      onClose: _exit,
                      onSettings: () => _scaffold.currentState?.openEndDrawer(),
                      onInteract: _showControls,
                      onBookmarks: () => _showBookmarks(script),
                      onMenu: (v) => _onMenu(v, script),
                      menuItems: const [
                        PopupMenuItem(
                          value: 'camera',
                          child: ListTile(
                            leading: Icon(Icons.videocam_outlined),
                            title: Text('Record with camera'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pip',
                          child: ListTile(
                            leading: Icon(
                              Icons.picture_in_picture_alt_outlined,
                            ),
                            title: Text('Picture-in-picture'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'overlay',
                          child: ListTile(
                            leading: Icon(Icons.layers_outlined),
                            title: Text('Float over other apps'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit script'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: ListTile(
                            leading: Icon(Icons.ios_share),
                            title: Text('Export / share'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.pc});
  final PlaybackController pc;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pc,
    builder: (_, _) {
      if (pc.status != PlaybackStatus.countdown) return const SizedBox();
      return IgnorePointer(
        child: Center(
          child: Text(
            '${pc.countdownRemaining}',
            style: const TextStyle(
              fontSize: 160,
              fontWeight: FontWeight.w200,
              color: Colors.white70,
              shadows: [Shadow(blurRadius: 24, color: Colors.black)],
            ),
          ),
        ),
      );
    },
  );
}
