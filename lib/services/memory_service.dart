import 'package:hive/hive.dart';
import '../models/user_memory.dart';

class MemoryService {
  static const String _boxName = 'memory';
  static const String _memoryKey = 'user_memory';

  Box<UserMemory> get _box => Hive.box<UserMemory>(_boxName);

  UserMemory getMemory() {
    var memory = _box.get(_memoryKey);
    if (memory == null) {
      memory = UserMemory(updatedAt: DateTime.now());
      _box.put(_memoryKey, memory);
    }
    return memory;
  }

  void saveMemory(UserMemory memory) {
    memory.updatedAt = DateTime.now();
    _box.put(_memoryKey, memory);
  }

  /// Форматирует UserMemory в текст системного промпта.
  String buildMemoryPrompt() {
    final memory = getMemory();
    final buf = StringBuffer();

    if (memory.profile != null && memory.profile!.isNotEmpty) {
      buf.writeln('[User profile]');
      buf.writeln(memory.profile);
    }

    if (memory.instructions != null && memory.instructions!.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('[Always-on instructions]');
      buf.writeln(memory.instructions);
    }

    if (memory.glossary != null && memory.glossary!.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('[Glossary]');
      buf.writeln(memory.glossary);
    }

    if (memory.facts != null && memory.facts!.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('[Known user facts]');
      buf.writeln(memory.facts);
    }

    return buf.toString().trim();
  }

  bool get hasMemory {
    final m = getMemory();
    return (m.profile?.isNotEmpty ?? false) ||
        (m.facts?.isNotEmpty ?? false) ||
        (m.instructions?.isNotEmpty ?? false) ||
        (m.glossary?.isNotEmpty ?? false);
  }
}
