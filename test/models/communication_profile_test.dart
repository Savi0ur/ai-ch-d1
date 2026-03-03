import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/models/communication_profile.dart';
import 'package:ai_api_app_claude/services/communication_profile_service.dart';
import '../helpers/hive_test_helper.dart';

void main() {
  group('CommunicationProfile — дефолтные значения', () {
    test('tone по умолчанию — neutral', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.tone, 'neutral');
    });

    test('depth по умолчанию — standard', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.depth, 'standard');
    });

    test('structure по умолчанию — no_structure', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.structure, 'no_structure');
    });

    test('role по умолчанию — partner', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.role, 'partner');
    });

    test('initiative по умолчанию — reactive', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.initiative, 'reactive');
    });
  });

  group('CommunicationProfileService.buildProfilePrompt', () {
    setUp(() async {
      await setUpHiveWithProfiles();
    });

    tearDown(() async {
      await tearDownHive();
    });

    test('генерирует непустую строку', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(svc.buildProfilePrompt(p), isNotEmpty);
    });

    test('содержит секцию [Communication style]', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(svc.buildProfilePrompt(p), contains('[Communication style]'));
    });

    test('меняется при разных параметрах', () {
      final svc = CommunicationProfileService();
      final p1 = CommunicationProfile(
        id: '1',
        name: 'P1',
        tone: 'friendly',
        depth: 'brief',
        updatedAt: DateTime.now(),
      );
      final p2 = CommunicationProfile(
        id: '2',
        name: 'P2',
        tone: 'strict',
        depth: 'expert',
        updatedAt: DateTime.now(),
      );
      expect(svc.buildProfilePrompt(p1), isNot(svc.buildProfilePrompt(p2)));
    });

    test('включает инструкцию тона friendly', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        tone: 'friendly',
        updatedAt: DateTime.now(),
      );
      expect(
        svc.buildProfilePrompt(p),
        contains(CommunicationProfile.tonePrompts['friendly']!),
      );
    });

    test('включает инструкцию глубины expert', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        depth: 'expert',
        updatedAt: DateTime.now(),
      );
      expect(
        svc.buildProfilePrompt(p),
        contains(CommunicationProfile.depthPrompts['expert']!),
      );
    });

    test('включает userProfile если задан', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
        userProfile: 'Андрей, Flutter-разработчик',
      );
      expect(
        svc.buildProfilePrompt(p),
        contains('Андрей, Flutter-разработчик'),
      );
    });

    test('включает userInstructions если заданы', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
        userInstructions: 'Отвечай только на русском',
      );
      expect(
        svc.buildProfilePrompt(p),
        contains('Отвечай только на русском'),
      );
    });

    test('не включает memory-секции если поля пустые', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      final prompt = svc.buildProfilePrompt(p);
      expect(prompt, isNot(contains('[Known user profile]')));
      expect(prompt, isNot(contains('[Known user facts]')));
    });
  });

  group('CommunicationProfileService.hasMemory', () {
    setUp(() async {
      await setUpHiveWithProfiles();
    });

    tearDown(() async {
      await tearDownHive();
    });

    test('возвращает false если все поля пустые', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(svc.hasMemory(p), isFalse);
    });

    test('возвращает true если userProfile задан', () {
      final svc = CommunicationProfileService();
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
        userProfile: 'Иван',
      );
      expect(svc.hasMemory(p), isTrue);
    });
  });

  group('CommunicationProfile — memory поля', () {
    test('userProfile null по умолчанию', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
      );
      expect(p.userProfile, isNull);
      expect(p.userFacts, isNull);
      expect(p.userInstructions, isNull);
      expect(p.userGlossary, isNull);
    });

    test('принимает явные значения памяти', () {
      final p = CommunicationProfile(
        id: '1',
        name: 'Test',
        updatedAt: DateTime.now(),
        userProfile: 'Иван',
        userFacts: '{"lang":"ru"}',
        userInstructions: 'Кратко',
        userGlossary: '{"LLM":"large language model"}',
      );
      expect(p.userProfile, 'Иван');
      expect(p.userFacts, '{"lang":"ru"}');
      expect(p.userInstructions, 'Кратко');
      expect(p.userGlossary, '{"LLM":"large language model"}');
    });
  });
}
