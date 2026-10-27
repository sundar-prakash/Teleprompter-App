import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../domain/models/teleprompter_settings.dart';
import '../../domain/services/srt_parser.dart';

enum PlaybackStatus { idle, countdown, playing, paused, finished }

/// Drives all reading modes from the frame ticker.
///
/// * continuous – scroll by `speed * dt`; optional auto-pause every N seconds
/// * singleLine – advance one line at a time with a short eased step
/// * paragraph  – scroll to each paragraph, hold for `paragraphPause`
/// * manual     – no automatic movement (user drags / uses jump buttons)
/// * subtitle   – a real-time clock selects the SRT cue to display
///
/// Scroll position advances by ticker-measured dt (capped for scroll modes so a
/// dropped frame never causes a jump). The subtitle clock is uncapped so cue
/// timing stays true to wall-clock time. The user may drag [scroll] at any
/// time; each tick re-reads the real position.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required TickerProvider vsync,
    required this._speed,
    int countdownSeconds = 3,
  }) : _countdown = countdownSeconds {
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController scroll = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _countdownLeft = 0;
  double _speed;
  int _countdown;

  ReadingMode _mode = ReadingMode.continuous;
  ReadingMode get mode => _mode;
  double _paragraphPause = 2;
  int _autoPauseEvery = 0;
  int _autoPauseFor = 5;
  List<SrtCue> _cues = const [];

  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackStatus get status => _status;
  bool get isPlaying =>
      _status == PlaybackStatus.playing || _status == PlaybackStatus.countdown;
  int get countdownRemaining => _countdownLeft.ceil();
  double get speed => _speed;

  /// Time spent actually moving (excludes pauses, holds and countdown).
  Duration elapsed = Duration.zero;

  static const _maxDt = 0.05;

  // ---- configuration ------------------------------------------------------

  void configure(TeleprompterSettings s, {List<SrtCue> cues = const []}) {
    _speed = s.pixelsPerSecond;
    _countdown = s.countdownSeconds;
    _paragraphPause = s.paragraphPause;
    _autoPauseEvery = s.autoPauseEvery;
    _autoPauseFor = s.autoPauseFor;
    _cues = cues;
    if (s.mode != _mode) {
      final wasPlaying = isPlaying;
      if (wasPlaying) pause();
      _mode = s.mode;
      _resetModeState();
    }
    notifyListeners();
  }

  set speed(double v) {
    _speed = v.clamp(5, 600).toDouble();
    notifyListeners();
  }

  set countdownSeconds(int v) => _countdown = v;

  // ---- layout info supplied by ScriptView ---------------------------------

  String? _layoutKey;
  String? _offsetsKey;
  List<double> Function()? _computeOffsets;
  List<double> _offsets = const [0];
  double lineStep = 60;

  /// Called by the view during build; cheap (no layout until requested).
  void attachLayout(
    String key,
    double lineStepPx,
    List<double> Function() compute,
  ) {
    _layoutKey = key;
    lineStep = lineStepPx;
    _computeOffsets = compute;
  }

  /// Scroll offsets at which each paragraph sits on the reading line.
  /// Computed lazily and memoised per layout.
  List<double> get paragraphOffsets {
    if (_offsetsKey != _layoutKey && _computeOffsets != null) {
      _offsets = _computeOffsets!();
      _offsetsKey = _layoutKey;
    }
    return _offsets;
  }

  int get currentParagraph {
    final o = paragraphOffsets;
    final pos = scroll.hasClients ? scroll.offset : 0;
    var i = 0;
    while (i + 1 < o.length && o[i + 1] <= pos + 2) {
      i++;
    }
    return i;
  }

  void scrollToParagraph(int index) {
    final o = paragraphOffsets;
    if (!scroll.hasClients || o.isEmpty) return;
    _jumpTo(o[index.clamp(0, o.length - 1)]);
  }

  // ---- progress -----------------------------------------------------------

  Duration _clock = Duration.zero; // subtitle clock
  Duration get subtitleTotal => _cues.isEmpty ? Duration.zero : _cues.last.end;

  SrtCue? get currentCue {
    for (final c in _cues) {
      if (_clock >= c.start && _clock < c.end) return c;
    }
    return null;
  }

  double get progress {
    if (_mode == ReadingMode.subtitle) {
      final t = subtitleTotal.inMicroseconds;
      return t == 0 ? 0 : (_clock.inMicroseconds / t).clamp(0, 1).toDouble();
    }
    if (!scroll.hasClients) return 0;
    final max = scroll.position.maxScrollExtent;
    return max <= 0 ? 0 : (scroll.offset / max).clamp(0, 1).toDouble();
  }

  /// Estimated time left at the current speed (null when it can't be known).
  Duration? get estimatedRemaining {
    if (_mode == ReadingMode.subtitle) return subtitleTotal - _clock;
    if (_mode == ReadingMode.manual || !scroll.hasClients) return null;
    final left = scroll.position.maxScrollExtent - scroll.offset;
    var secs = left / _speed;
    if (_mode == ReadingMode.paragraph) {
      final o = paragraphOffsets;
      secs +=
          _paragraphPause *
          (o.length - 1 - currentParagraph).clamp(0, o.length);
    }
    if (_autoPauseEvery > 0) {
      secs += (secs / _autoPauseEvery).floor() * _autoPauseFor;
    }
    return Duration(milliseconds: (secs * 1000).round());
  }

  bool get isHolding => _hold > 0;
  int get holdRemaining => _hold.ceil();

  // ---- transport ----------------------------------------------------------

  double _hold = 0;
  double _sinceRest = 0;
  double _lineAcc = 0;
  double _stepT = 1;
  double _stepFrom = 0;
  double _stepTo = 0;
  int _paraTarget = -1;

  void _resetModeState() {
    _hold = 0;
    _sinceRest = 0;
    _lineAcc = 0;
    _stepT = 1;
    _paraTarget = -1;
  }

  bool get canAutoPlay => _mode != ReadingMode.manual;

  void play() {
    if (!canAutoPlay) return;
    if (_mode == ReadingMode.subtitle && _cues.isEmpty) return;
    if (_status == PlaybackStatus.finished) restart(autoPlay: false);
    if (_status == PlaybackStatus.idle && _countdown > 0) {
      _countdownLeft = _countdown.toDouble();
      _set(PlaybackStatus.countdown);
    } else {
      _set(PlaybackStatus.playing);
    }
    _last = Duration.zero;
    _paraTarget = -1;
    if (!_ticker.isActive) _ticker.start();
  }

  void pause() {
    if (!isPlaying) return;
    _ticker.stop();
    _set(PlaybackStatus.paused);
  }

  void toggle() => isPlaying ? pause() : play();

  /// Stops and rewinds to the start.
  void stop() {
    _ticker.stop();
    elapsed = Duration.zero;
    _clock = Duration.zero;
    _resetModeState();
    if (scroll.hasClients) scroll.jumpTo(0);
    _set(PlaybackStatus.idle);
  }

  void restart({bool autoPlay = true}) {
    stop();
    if (autoPlay) play();
  }

  void _jumpTo(double px) {
    final p = scroll.position;
    scroll.jumpTo(px.clamp(0, p.maxScrollExtent).toDouble());
    _paraTarget = -1;
    _stepT = 1;
    notifyListeners();
  }

  /// Step backwards/forwards: a cue (subtitle), paragraph, line, or
  /// [pixels] (continuous/manual).
  void jump(int dir, double pixels) {
    switch (_mode) {
      case ReadingMode.subtitle:
        final i = _cues.indexWhere((c) => c.end > _clock);
        final base = i < 0 ? _cues.length - 1 : i;
        final to = (base + dir).clamp(0, _cues.length - 1);
        if (_cues.isNotEmpty) _clock = _cues[to].start;
        notifyListeners();
      case ReadingMode.paragraph:
        if (!scroll.hasClients) return;
        final o = paragraphOffsets;
        final cur = currentParagraph;
        // Going back from the middle of a paragraph restarts that paragraph.
        final atStart = (scroll.offset - o[cur]).abs() < 4;
        scrollToParagraph(dir < 0 && !atStart ? cur : cur + dir);
      case ReadingMode.singleLine:
        if (scroll.hasClients) _jumpTo(scroll.offset + dir * lineStep);
      default:
        if (scroll.hasClients) _jumpTo(scroll.offset + dir * pixels);
    }
  }

  void seek(double fraction) {
    final f = fraction.clamp(0, 1).toDouble();
    if (_mode == ReadingMode.subtitle) {
      _clock = Duration(
        microseconds: (subtitleTotal.inMicroseconds * f).round(),
      );
    } else if (scroll.hasClients) {
      _jumpTo(scroll.position.maxScrollExtent * f);
    }
    if (_status == PlaybackStatus.finished) _set(PlaybackStatus.paused);
    notifyListeners();
  }

  // ---- ticking ------------------------------------------------------------

  void _onTick(Duration t) {
    final raw = _last == Duration.zero ? 0.0 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    final dt = math.min(raw, _maxDt);

    if (_status == PlaybackStatus.countdown) {
      _countdownLeft -= raw;
      _countdownLeft <= 0 ? _set(PlaybackStatus.playing) : notifyListeners();
      return;
    }
    if (_status != PlaybackStatus.playing) return;

    if (_mode == ReadingMode.subtitle) {
      _clock += Duration(microseconds: (raw * 1e6).round());
      elapsed += Duration(microseconds: (raw * 1e6).round());
      if (_clock >= subtitleTotal) {
        _clock = subtitleTotal;
        _finish();
      } else {
        notifyListeners();
      }
      return;
    }
    if (!scroll.hasClients) return;

    if (_hold > 0) {
      _hold -= raw;
      notifyListeners();
      return;
    }
    switch (_mode) {
      case ReadingMode.continuous:
        _tickContinuous(dt);
      case ReadingMode.singleLine:
        _tickLine(dt);
      case ReadingMode.paragraph:
        _tickParagraph(dt);
      default:
        break;
    }
  }

  void _advanceTo(double next) {
    final max = scroll.position.maxScrollExtent;
    if (next >= max) {
      scroll.jumpTo(max);
      _finish();
    } else {
      scroll.jumpTo(next);
      notifyListeners();
    }
  }

  void _tickContinuous(double dt) {
    elapsed += Duration(microseconds: (dt * 1e6).round());
    _sinceRest += dt;
    if (_autoPauseEvery > 0 && _sinceRest >= _autoPauseEvery) {
      _sinceRest = 0;
      _hold = _autoPauseFor.toDouble();
    }
    _advanceTo(scroll.position.pixels + _speed * dt);
  }

  void _tickLine(double dt) {
    elapsed += Duration(microseconds: (dt * 1e6).round());
    if (_stepT < 1) {
      _stepT = math.min(1, _stepT + dt / 0.18);
      final e = Curves.easeInOut.transform(_stepT);
      _advanceTo(_stepFrom + (_stepTo - _stepFrom) * e);
      return;
    }
    _lineAcc += _speed * dt;
    if (_lineAcc >= lineStep) {
      _lineAcc -= lineStep;
      _stepFrom = scroll.position.pixels;
      _stepTo = _stepFrom + lineStep;
      _stepT = 0;
    }
    notifyListeners();
  }

  void _tickParagraph(double dt) {
    final o = paragraphOffsets;
    final max = scroll.position.maxScrollExtent;
    if (_paraTarget < 0) _paraTarget = currentParagraph + 1;
    final target = _paraTarget >= o.length
        ? max
        : math.min(o[_paraTarget], max);
    elapsed += Duration(microseconds: (dt * 1e6).round());
    final next = scroll.position.pixels + _speed * dt;
    if (next >= target) {
      scroll.jumpTo(target);
      if (target >= max) return _finish();
      _paraTarget++;
      _hold = _paragraphPause;
      notifyListeners();
    } else {
      scroll.jumpTo(next);
      notifyListeners();
    }
  }

  void _finish() {
    _ticker.stop();
    _set(PlaybackStatus.finished);
  }

  void _set(PlaybackStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    scroll.dispose();
    super.dispose();
  }
}
