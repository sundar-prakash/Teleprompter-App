import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/file_script_repository.dart';
import 'package:teleprompter/domain/models/script.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('scripts'));
  tearDown(() => dir.deleteSync(recursive: true));

  Script make(String id) {
    final now = DateTime(2026, 1, 1);
    return Script(
      id: id,
      title: 'T$id',
      body: 'b',
      originalBody: 'orig',
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
  }

  test('save, load, delete; original body is preserved', () async {
    final repo = FileScriptRepository(Directory('${dir.path}/nested'));
    await repo.save(make('a'));
    await repo.save(make('b'));
    final all = await repo.loadAll();
    expect(all.map((s) => s.id).toSet(), {'a', 'b'});
    expect(all.first.originalBody, 'orig');
    await repo.delete('a');
    expect((await repo.loadAll()).single.id, 'b');
  });

  test('a corrupt file does not break loading others', () async {
    final repo = FileScriptRepository(dir);
    await repo.save(make('ok'));
    File('${dir.path}/bad.json').writeAsStringSync('{not json');
    expect((await repo.loadAll()).single.id, 'ok');
  });
}
