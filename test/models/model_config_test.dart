import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/models/model_config.dart';

void main() {
  group('ModelConfig', () {
    group('all', () {
      test('содержит 6 моделей', () {
        expect(ModelConfig.all.length, 6);
      });

      test('содержит все ожидаемые id', () {
        final ids = ModelConfig.all.map((m) => m.id).toSet();
        expect(ids, containsAll([
          'openai/gpt-5.2',
          'openai/gpt-5.1',
          'openai/gpt-4.1',
          'openai/o3',
          'openai/gpt-4o-mini',
          'openai/gpt-3.5-turbo',
        ]));
      });

      test('у всех моделей положительный contextWindow', () {
        for (final m in ModelConfig.all) {
          expect(m.contextWindow, greaterThan(0), reason: '${m.id} contextWindow должен быть > 0');
        }
      });

      test('у всех моделей положительные цены', () {
        for (final m in ModelConfig.all) {
          expect(m.inputPrice, greaterThan(0), reason: '${m.id} inputPrice должен быть > 0');
          expect(m.outputPrice, greaterThan(0), reason: '${m.id} outputPrice должен быть > 0');
        }
      });
    });

    group('getPricing', () {
      test('возвращает корректные цены для gpt-4o-mini', () {
        final p = ModelConfig.getPricing('openai/gpt-4o-mini');
        expect(p, isNotNull);
        expect(p!.$1, 0.15);
        expect(p.$2, 0.60);
      });

      test('возвращает корректные цены для o3', () {
        final p = ModelConfig.getPricing('openai/o3');
        expect(p, isNotNull);
        expect(p!.$1, 10.00);
        expect(p.$2, 40.00);
      });

      test('возвращает null для неизвестной модели', () {
        expect(ModelConfig.getPricing('unknown/model'), isNull);
      });

      test('возвращает null для пустой строки', () {
        expect(ModelConfig.getPricing(''), isNull);
      });
    });

    group('getContextWindow', () {
      test('gpt-5.2 — 1M токенов', () {
        expect(ModelConfig.getContextWindow('openai/gpt-5.2'), 1048576);
      });

      test('o3 — 200K токенов', () {
        expect(ModelConfig.getContextWindow('openai/o3'), 200000);
      });

      test('gpt-3.5-turbo — 16K токенов', () {
        expect(ModelConfig.getContextWindow('openai/gpt-3.5-turbo'), 16385);
      });

      test('возвращает null для неизвестной модели', () {
        expect(ModelConfig.getContextWindow('unknown/model'), isNull);
      });
    });

    group('dropdownItems', () {
      test('содержит 6 элементов', () {
        expect(ModelConfig.dropdownItems.length, 6);
      });

      test('корректно маппит id → label', () {
        expect(ModelConfig.dropdownItems['openai/gpt-5.2'], 'GPT-5.2');
        expect(ModelConfig.dropdownItems['openai/gpt-4o-mini'], 'GPT-4o Mini');
        expect(ModelConfig.dropdownItems['openai/gpt-3.5-turbo'], 'GPT-3.5 Turbo');
      });

      test('не содержит неизвестных ключей', () {
        expect(ModelConfig.dropdownItems.containsKey('unknown'), isFalse);
      });
    });
  });
}
