enum CameraLayout {
  scriptAbove('Script above camera'),
  scriptBelow('Script below camera'),
  transparentOverlay('Transparent overlay'),
  underLens('Compact strip under lens'),
  split('Split screen'),
  floating('Floating script box');

  const CameraLayout(this.label);
  final String label;
}

/// Resolution presets exposed by the Android camera plugin.
enum VideoQuality {
  p480('480p', 0),
  p720('720p', 1),
  p1080('1080p', 2),
  p2160('4K', 3);

  const VideoQuality(this.label, this.rank);
  final String label;
  final int rank;
}

class CameraPrefs {
  const CameraPrefs({
    this.layout = CameraLayout.underLens,
    this.quality = VideoQuality.p1080,
    this.fps = 30,
    this.scriptOpacity = 0.55,
    this.scriptHeight = 0.38,
    this.stopWithScript = true,
    this.frontCamera = true,
    this.scriptOffset = 0.25,
    this.fontScale = 0.6,
  });

  final CameraLayout layout;
  final VideoQuality quality;
  final int fps;

  /// Background opacity (0–1) behind script text over the preview.
  final double scriptOpacity;

  /// Fraction of screen height given to the script area.
  final double scriptHeight;
  final bool stopWithScript;
  final bool frontCamera;

  /// Vertical position (0–1) of the overlay / floating script box.
  final double scriptOffset;

  /// Multiplier on the main font size while in camera mode.
  final double fontScale;

  CameraPrefs copyWith({
    CameraLayout? layout,
    VideoQuality? quality,
    int? fps,
    double? scriptOpacity,
    double? scriptHeight,
    bool? stopWithScript,
    bool? frontCamera,
    double? scriptOffset,
    double? fontScale,
  }) => CameraPrefs(
    layout: layout ?? this.layout,
    quality: quality ?? this.quality,
    fps: fps ?? this.fps,
    scriptOpacity: scriptOpacity ?? this.scriptOpacity,
    scriptHeight: scriptHeight ?? this.scriptHeight,
    stopWithScript: stopWithScript ?? this.stopWithScript,
    frontCamera: frontCamera ?? this.frontCamera,
    scriptOffset: scriptOffset ?? this.scriptOffset,
    fontScale: fontScale ?? this.fontScale,
  );

  Map<String, Object?> toJson() => {
    'layout': layout.name,
    'quality': quality.name,
    'fps': fps,
    'scriptOpacity': scriptOpacity,
    'scriptHeight': scriptHeight,
    'stopWithScript': stopWithScript,
    'frontCamera': frontCamera,
    'scriptOffset': scriptOffset,
    'fontScale': fontScale,
  };

  factory CameraPrefs.fromJson(Map<String, Object?> j) {
    const d = CameraPrefs();
    return CameraPrefs(
      layout: CameraLayout.values.asNameMap()[j['layout']] ?? d.layout,
      quality: VideoQuality.values.asNameMap()[j['quality']] ?? d.quality,
      fps: ((j['fps'] as num?)?.toInt() ?? d.fps).clamp(15, 60),
      scriptOpacity:
          ((j['scriptOpacity'] as num?)?.toDouble() ?? d.scriptOpacity).clamp(
            0.0,
            1.0,
          ),
      scriptHeight: ((j['scriptHeight'] as num?)?.toDouble() ?? d.scriptHeight)
          .clamp(0.15, 0.7),
      stopWithScript: j['stopWithScript'] as bool? ?? d.stopWithScript,
      frontCamera: j['frontCamera'] as bool? ?? d.frontCamera,
      scriptOffset: ((j['scriptOffset'] as num?)?.toDouble() ?? d.scriptOffset)
          .clamp(0.0, 0.8),
      fontScale: ((j['fontScale'] as num?)?.toDouble() ?? d.fontScale).clamp(
        0.3,
        1.5,
      ),
    );
  }
}
