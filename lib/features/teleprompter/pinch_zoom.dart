import 'package:flutter/widgets.dart';

/// Two-finger pinch that reports a scale factor relative to the gesture start.
/// Uses raw pointer events (not the gesture arena) so it never fights with
/// scrolling or taps. Only active while [enabled].
class PinchZoom extends StatefulWidget {
  const PinchZoom({
    super.key,
    required this.enabled,
    required this.onStart,
    required this.onScale,
    required this.onEnd,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onStart;
  final ValueChanged<double> onScale;
  final VoidCallback onEnd;
  final Widget child;

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  final _pointers = <int, Offset>{};
  double? _startDistance;

  double get _distance {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _maybeStart() {
    if (_pointers.length == 2 && _startDistance == null && widget.enabled) {
      final d = _distance;
      if (d > 10) {
        _startDistance = d;
        widget.onStart();
      }
    }
  }

  void _end() {
    if (_startDistance != null) {
      _startDistance = null;
      widget.onEnd();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) {
      _pointers[e.pointer] = e.position;
      _maybeStart();
    },
    onPointerMove: (e) {
      _pointers[e.pointer] = e.position;
      final start = _startDistance;
      if (start != null && _pointers.length == 2) {
        widget.onScale(_distance / start);
      } else {
        _maybeStart();
      }
    },
    onPointerUp: (e) {
      _pointers.remove(e.pointer);
      if (_pointers.length < 2) _end();
    },
    onPointerCancel: (e) {
      _pointers.remove(e.pointer);
      if (_pointers.length < 2) _end();
    },
    child: widget.child,
  );
}
