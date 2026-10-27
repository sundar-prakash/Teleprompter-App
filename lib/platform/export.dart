import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models/script.dart';

/// Writes the script to a temp .txt and opens the Android share sheet, which
/// lets the user save to Files/Drive or send it to another app.
Future<void> exportScript(Script script) async {
  final dir = await getTemporaryDirectory();
  final safe = script.title.replaceAll(RegExp(r'[^\w\- ]+'), '_').trim();
  final file = File(p.join(dir.path, '${safe.isEmpty ? 'script' : safe}.txt'));
  await file.writeAsString(script.body);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: script.title),
  );
}
