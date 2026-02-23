# CLAUDE.md

## Язык

Общение по проекту ведётся на русском языке.

## Обзор

Flutter-приложение для чата с LLM. Поддерживает многооборотные диалоги с сохранением истории (Hive). Стриминг ответов через SSE от OpenAI-совместимого API (прокси `openai.api.proxyapi.ru`).

## Команды

```bash
flutter pub get          # Установка зависимостей
flutter analyze          # Статический анализ (flutter_lints)
flutter test             # Тесты
flutter run -d windows   # Запуск Windows
flutter run -d chrome    # Запуск Web
flutter build apk        # Сборка Android APK
```

## Структура

```
lib/
  main.dart                       # Точка входа, Hive init, тема (светлая/тёмная)
  models/
    chat.dart                     # Chat, ChatMessage + ручные Hive TypeAdapters
    model_config.dart             # Единая конфигурация моделей (id, label, pricing)
  services/
    api_service.dart              # SSE-стриминг к /v1/chat/completions
    chat_repository.dart          # CRUD чатов и сообщений (Hive)
  screens/
    chat_controller.dart          # ChatController (ChangeNotifier) — состояние и бизнес-логика
    chat_screen.dart              # Главный экран: UI, подписка через ListenableBuilder
  widgets/
    chat_drawer.dart              # Боковая панель / drawer с историей чатов
    message_bubble.dart           # Пузырёк сообщения (user/assistant)
    chat_input.dart               # Поле ввода + кнопка send/stop
    request_log_panel.dart        # Лог запроса и информация об ответе
```

## Ключевые решения

- **Hive** для хранения (не SQLite) — работает на всех платформах включая Web, без нативных зависимостей
- **Ручные TypeAdapters** вместо кодогенерации — нет dev-зависимостей на build_runner/hive_generator
- **Адаптивный layout** — sidebar на экранах >900px, drawer на узких
- **SSE-парсинг вручную** — без сторонних SSE-библиотек, буферизация неполных строк в `ApiService`

## Конфигурация

- API ключ: `.env` файл в корне (`API_KEY=...`), загружается через `flutter_dotenv`, включён в assets
- Base URL: захардкожен в `ApiService._baseUrl`
- Модели: единый список в `ModelConfig.all` (`lib/models/model_config.dart`)
- Hive боксы: `chats`, `messages`, `settings`
- Тема (dark/light): сохраняется в Hive `settings` бокс

## Зависимости

| Пакет | Назначение |
|---|---|
| `flutter_dotenv` | Загрузка .env |
| `http` | HTTP-клиент для стриминга |
| `hive` / `hive_flutter` | NoSQL хранилище |
| `uuid` | Генерация ID чатов и сообщений |
| `path_provider` | Пути файловой системы для Hive |

## Платформы

Android, Windows, Web
