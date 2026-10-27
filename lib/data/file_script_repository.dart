import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/log.dart';
import '../domain/models/script.dart';
import '../domain/repositories/script_repository.dart';

/// One JSON file per script. Writes are atomic (temp file + rename) so a crash
/// mid-write can never corrupt an existing script.
class FileScriptRepository implements ScriptRepository {
  FileScriptRepository(this._dir);
  final Directory _dir;

  File _file(String id) => File(p.join(_dir.path, '$id.json'));

  @override
  Future<List<Script>> loadAll() async {
    if (!await _dir.exists()) return [];
    final out = <Script>[];
    await for (final e in _dir.list()) {
      if (e is! File || p.extension(e.path) != '.json') continue;
      try {
        final json = jsonDecode(await e.readAsString()) as Map<String, Object?>;
        out.add(Script.fromJson(json));
      } catch (err, st) {
        // Skip unreadable files rather than failing the whole library.
        logError('loadScript ${e.path}', err, st);
      }
    }
    return out;
  }

  @override
  Future<void> save(Script script) async {
    await _dir.create(recursive: true);
    final tmp = File('${_file(script.id).path}.tmp');
    await tmp.writeAsString(jsonEncode(script.toJson()), flush: true);
    await tmp.rename(_file(script.id).path);
  }

  @override
  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}
