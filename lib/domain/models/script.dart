import 'package:flutter/foundation.dart';

import '../services/srt_parser.dart';

enum SourceFormat { manual, txt, md, srt, docx, pdf }

@immutable
class Script {
  const Script({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    this.originalBody,
    this.sourceFormat = SourceFormat.manual,
    this.sourceFileName,
    this.cues = const [],
    this.bookmarks = const [],
    this.highlights = const [],
  });

  final String id;
  final String title;

  /// The editable script text shown in the teleprompter.
  final String body;

  /// Text exactly as extracted at import time. Never modified by edits.
  final String? originalBody;
  final SourceFormat sourceFormat;
  final String? sourceFileName;

  /// Subtitle timing kept from an SRT import (enables Subtitle mode).
  final List<SrtCue> cues;

  /// Paragraph indexes. Shift if paragraphs are inserted/removed while editing.
  final List<int> bookmarks;
  final List<int> highlights;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastOpenedAt;

  bool get isModifiedFromOriginal =>
      originalBody != null && originalBody != body;

  Script copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    List<int>? bookmarks,
    List<int>? highlights,
  }) => Script(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    originalBody: originalBody,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    cues: cues,
    bookmarks: bookmarks ?? this.bookmarks,
    highlights: highlights ?? this.highlights,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'body': body,
    'originalBody': originalBody,
    'sourceFormat': sourceFormat.name,
    'sourceFileName': sourceFileName,
    'cues': [
      for (final c in cues)
        [c.index, c.start.inMilliseconds, c.end.inMilliseconds, c.text],
    ],
    'bookmarks': bookmarks,
    'highlights': highlights,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
  };

  factory Script.fromJson(Map<String, Object?> j) => Script(
    id: j['id']! as String,
    title: j['title']! as String,
    body: j['body']! as String,
    originalBody: j['originalBody'] as String?,
    sourceFormat:
        SourceFormat.values.asNameMap()[j['sourceFormat']] ??
        SourceFormat.manual,
    sourceFileName: j['sourceFileName'] as String?,
    cues: [
      for (final c in (j['cues'] as List?) ?? const [])
        SrtCue(
          c[0] as int,
          Duration(milliseconds: c[1] as int),
          Duration(milliseconds: c[2] as int),
          c[3] as String,
        ),
    ],
    bookmarks: [...((j['bookmarks'] as List?) ?? const []).cast<int>()],
    highlights: [...((j['highlights'] as List?) ?? const []).cast<int>()],
    createdAt: DateTime.parse(j['createdAt']! as String),
    updatedAt: DateTime.parse(j['updatedAt']! as String),
    lastOpenedAt: DateTime.parse(j['lastOpenedAt']! as String),
  );
}
