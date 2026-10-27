import 'dart:convert';
import 'dart:typed_data';

/// Decodes text bytes: UTF-8 (with/without BOM), UTF-16 LE/BE (BOM), falling
/// back to Latin-1 so legacy files still open instead of failing.
String decodeText(Uint8List b) {
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    return _utf16(b, 2, Endian.little);
  }
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    return _utf16(b, 2, Endian.big);
  }
  try {
    final start = b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF
        ? 3
        : 0;
    return utf8.decode(b.sublist(start));
  } on FormatException {
    return latin1.decode(b);
  }
}

String _utf16(Uint8List b, int start, Endian e) {
  final d = ByteData.sublistView(b);
  return String.fromCharCodes([
    for (var i = start; i + 1 < b.length; i += 2) d.getUint16(i, e),
  ]);
}

String normalizeNewlines(String s) =>
    s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
