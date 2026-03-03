import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/services/memory_service.dart';
import 'package:ai_api_app_claude/models/user_memory.dart';
import '../helpers/hive_test_helper.dart';

void main() {
  late MemoryService service;

  setUp(() async {
    await setUpHive();
    service = MemoryService();
  });

  tearDown(() async {
    await tearDownHive();
  });

  group('getMemory', () {
    test('создаёт пустую память при первом вызове', () {
      final memory = service.getMemory();
      expect(memory, isNotNull);
      expect(memory.profile, isNull);
      expect(memory.facts, isNull);
      expect(memory.instructions, isNull);
      expect(memory.glossary, isNull);
    });

    test('возвращает одну и ту же запись при повторном вызове', () {
      service.getMemory();
      final m1 = service.getMemory();
      final m2 = service.getMemory();
      expect(m1.updatedAt, equals(m2.updatedAt));
    });
  });

  group('saveMemory', () {
    test('сохраняет и возвращает обновлённые данные', () {
      final memory = service.getMemory();
      memory.profile = 'Иван, разработчик';
      service.saveMemory(memory);

      expect(service.getMemory().profile, 'Иван, разработчик');
    });

    test('обновляет updatedAt', () {
      final memory = service.getMemory();
      final before = memory.updatedAt;
      memory.profile = 'test';
      service.saveMemory(memory);

      expect(service.getMemory().updatedAt.isAfter(before) ||
          service.getMemory().updatedAt.isAtSameMomentAs(before), isTrue);
    });
  });

  group('hasMemory', () {
    test('возвращает false для пустой памяти', () {
      expect(service.hasMemory, isFalse);
    });

    test('возвращает true если установлен profile', () {
      final m = service.getMemory();
      m.profile = 'Иван';
      service.saveMemory(m);
      expect(service.hasMemory, isTrue);
    });

    test('возвращает true если установлены facts', () {
      final m = service.getMemory();
      m.facts = '{"profession": "dev"}';
      service.saveMemory(m);
      expect(service.hasMemory, isTrue);
    });

    test('возвращает true если установлены instructions', () {
      final m = service.getMemory();
      m.instructions = 'Отвечай кратко';
      service.saveMemory(m);
      expect(service.hasMemory, isTrue);
    });

    test('возвращает true если установлен glossary', () {
      final m = service.getMemory();
      m.glossary = '{"LTM": "Long-term memory"}';
      service.saveMemory(m);
      expect(service.hasMemory, isTrue);
    });

    test('возвращает false если все поля пустые строки', () {
      final m = service.getMemory();
      m.profile = '';
      m.facts = '';
      m.instructions = '';
      m.glossary = '';
      service.saveMemory(m);
      expect(service.hasMemory, isFalse);
    });
  });

  group('buildMemoryPrompt', () {
    test('возвращает пустую строку для пустой памяти', () {
      expect(service.buildMemoryPrompt(), isEmpty);
    });

    test('включает секцию [User profile] если profile задан', () {
      final m = service.getMemory();
      m.profile = 'Иван, разработчик';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, contains('[User profile]'));
      expect(prompt, contains('Иван, разработчик'));
    });

    test('включает секцию [Always-on instructions] если instructions задан', () {
      final m = service.getMemory();
      m.instructions = 'Отвечай кратко';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, contains('[Always-on instructions]'));
      expect(prompt, contains('Отвечай кратко'));
    });

    test('включает секцию [Glossary] если glossary задан', () {
      final m = service.getMemory();
      m.glossary = '{"SSE": "Server-Sent Events"}';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, contains('[Glossary]'));
      expect(prompt, contains('SSE'));
    });

    test('включает секцию [Known user facts] если facts заданы', () {
      final m = service.getMemory();
      m.facts = '{"profession": "developer"}';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, contains('[Known user facts]'));
      expect(prompt, contains('developer'));
    });

    test('включает все секции когда все поля заполнены', () {
      final m = UserMemory(
        profile: 'Иван',
        facts: '{"role": "dev"}',
        instructions: 'Будь краток',
        glossary: '{"API": "интерфейс"}',
        updatedAt: DateTime.now(),
      );
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, contains('[User profile]'));
      expect(prompt, contains('[Always-on instructions]'));
      expect(prompt, contains('[Glossary]'));
      expect(prompt, contains('[Known user facts]'));
    });

    test('не включает секции для пустых полей', () {
      final m = service.getMemory();
      m.profile = 'Иван';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, isNot(contains('[Always-on instructions]')));
      expect(prompt, isNot(contains('[Glossary]')));
      expect(prompt, isNot(contains('[Known user facts]')));
    });

    test('результат не начинается и не заканчивается пробелами', () {
      final m = service.getMemory();
      m.profile = 'Иван';
      service.saveMemory(m);

      final prompt = service.buildMemoryPrompt();
      expect(prompt, equals(prompt.trim()));
    });
  });
}
