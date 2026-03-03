# CLAUDE.md

## Язык

Общение по проекту ведётся на русском языке.

## Обзор

Flutter LLM-агент с многоуровневой памятью, управлением контекстом и анализом пользователя. Поддерживает многооборотные диалоги с историей (Hive), стриминг ответов через SSE (OpenAI-совместимый API, прокси `openai.api.proxyapi.ru`), четыре стратегии контекста, три слоя памяти и тонкую настройку параметров запроса.

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
  main.dart                         # Точка входа, Hive init, тема (светлая/тёмная)
  models/
    chat.dart                       # Chat, ChatMessage + ручные Hive TypeAdapters
    model_config.dart               # Конфигурация моделей (id, label, pricing, contextWindow)
    user_memory.dart                # Долгосрочная память пользователя + TypeAdapter
  services/
    api_service.dart                # SSE-стриминг, суммаризация, извлечение памяти/фактов
    chat_repository.dart            # CRUD чатов и сообщений (Hive), создание веток
    memory_service.dart             # Управление долгосрочной памятью пользователя
  screens/
    chat_controller.dart            # ChatController (ChangeNotifier) — состояние и бизнес-логика
    chat_screen.dart                # Главный экран: UI, настройки, лог запросов
  widgets/
    chat_drawer.dart                # Боковая панель: история чатов, редактор памяти
    message_bubble.dart             # Пузырёк сообщения (user/assistant) + кнопка ветвления
    chat_input.dart                 # Поле ввода + кнопка send/stop
    request_log_panel.dart          # Лог запроса, токены, стоимость
    working_memory_panel.dart       # Визуализация рабочей памяти (цель, шаги, результаты)
```

## Трёхуровневая система памяти

### 1. Рабочая память (Working Memory) — per-chat, краткосрочная
Хранится в `Chat.workingMemory` (JSON).
Структура: `{goal, steps[], current_step, results, notes}`.
Автоматически извлекается из диалога через `ApiService.extractWorkingMemory()` после каждого ответа (если включена).
Отображается в `WorkingMemoryPanel`, поддерживает ручное редактирование и сброс.

### 2. Долгосрочная память пользователя (LTM) — глобальная, persistent
Хранится в `UserMemory` (Hive box `memory`), управляется `MemoryService`.
Поля: `profile` (текст), `facts` (JSON), `instructions` (всегда-активные), `glossary` (JSON).
Автоматически обновляется через `ApiService.extractUserMemory()` после каждого ответа.
Редактируется вручную через `_MemoryEditorDialog` в боковой панели.
Включается в system prompt через `MemoryService.buildMemoryPrompt()`.

### 3. Контекстная история — per-chat
Управляется выбранной стратегией контекста (см. ниже).
Поля в `Chat`: `summary`, `summarizedUpTo`, `facts` (для sticky_facts).

## Четыре стратегии управления контекстом

| Стратегия | Поведение |
| --- | --- |
| `summarization` | Старые сообщения сжимаются в `Chat.summary` при достижении 85% окна контекста. Суммаризация через GPT-4o Mini. |
| `sliding_window` | Передаются только последние N сообщений (`Chat.slidingWindowSize`). |
| `sticky_facts` | Последние N сообщений + извлечённые ключевые факты как system-сообщение. |
| `branching` | Все сообщения, без ограничений. Ветвление через кнопку на пузырьке сообщения. |

Стратегия задаётся в настройках чата, сохраняется в `Chat.contextStrategy`.

## Ключевые решения

- **Hive** для хранения (не SQLite) — работает на всех платформах включая Web, без нативных зависимостей
- **Ручные TypeAdapters** вместо кодогенерации — нет зависимостей на build_runner/hive_generator
- **Адаптивный layout** — sidebar на экранах >900px, drawer на узких
- **SSE-парсинг вручную** — без сторонних SSE-библиотек, буферизация неполных строк в `ApiService`
- **GPT-4o Mini для служебных задач** — суммаризация, извлечение памяти и фактов (фиксированная модель, не зависит от выбора пользователя)
- **ChangeNotifier** — минималистичное управление состоянием без лишних зависимостей
- **Оценка токенов** — ~1 токен = 3 символа, используется для автоматического запуска суммаризации

## Конфигурация

- API ключ: `.env` файл в корне (`API_KEY=...`), загружается через `flutter_dotenv`, включён в assets
- Base URL: захардкожен в `ApiService._baseUrl` (`https://openai.api.proxyapi.ru/v1`)
- Модели: единый список в `ModelConfig.all` (`lib/models/model_config.dart`)
- Hive боксы: `chats`, `messages`, `memory`, `settings`
- Тема (dark/light): сохраняется в Hive `settings` бокс

## Тонкая настройка (Advanced Settings)

Доступна в модальном окне настроек (`_showSettings` в `chat_screen.dart`):

- **System Prompt** — произвольные инструкции per-chat (многострочный ввод)
- **Max Tokens** — лимит токенов на ответ
- **Stop Sequence** — кастомный стоп-токен
- **Temperature** — слайдер 0.0–2.0
- **Context Strategy** — выбор стратегии
- **Sliding Window Size** — размер окна (для sliding_window и sticky_facts)
- **Working Memory** — включение/выключение автообновления рабочей памяти

## Модели

| Модель                  | Input      | Output     | Контекст |
|-------------------------|------------|------------|----------|
| `openai/gpt-5.2`        | $2.50/1M   | $10.00/1M  | 1M       |
| `openai/gpt-5.1`        | $2.00/1M   | $8.00/1M   | 1M       |
| `openai/gpt-4.1`        | $2.00/1M   | $8.00/1M   | 1M       |
| `openai/o3`             | $10.00/1M  | $40.00/1M  | 200K     |
| `openai/gpt-4o-mini`    | $0.15/1M   | $0.60/1M   | 128K     |
| `openai/gpt-3.5-turbo`  | $0.50/1M   | $1.50/1M   | 16K      |

Служебная модель (суммаризация, память): `openai/gpt-4o-mini` (фиксировано).

## Зависимости

| Пакет                   | Назначение                            |
|-------------------------|---------------------------------------|
| `flutter_dotenv`        | Загрузка .env                         |
| `http`                  | HTTP-клиент для стриминга             |
| `hive` / `hive_flutter` | NoSQL хранилище                       |
| `uuid`                  | Генерация ID чатов и сообщений        |
| `path_provider`         | Пути файловой системы для Hive        |

## Платформы

Android, Windows, Web