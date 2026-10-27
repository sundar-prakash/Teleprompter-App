import '../models/script.dart';

abstract interface class ScriptRepository {
  Future<List<Script>> loadAll();
  Future<void> save(Script script);
  Future<void> delete(String id);
}
