# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Язык общения

Общение по проекту ведётся на русском языке.

## Project Overview

Flutter chat app with multi-turn conversations and chat history. Streams responses from an OpenAI-compatible API via a proxy at `openai.api.proxyapi.ru`. Supports multiple simultaneous chats with persistent storage via Hive.

## Build & Run Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d windows   # Run on Windows desktop
flutter run -d chrome    # Run on web
flutter build apk        # Build Android APK
flutter analyze          # Run static analysis (uses flutter_lints)
flutter test             # Run tests
```

## Architecture

```
lib/
  main.dart                       # Entry point, Hive init, theme management
  models/
    chat.dart                     # Chat & ChatMessage models + Hive TypeAdapters
  services/
    api_service.dart              # Streaming API client (SSE parsing, cancellation)
    chat_repository.dart          # CRUD for chats and messages via Hive
  screens/
    chat_screen.dart              # Main chat screen (message list, input, drawer)
  widgets/
    chat_drawer.dart              # Sidebar/drawer with chat history list
    message_bubble.dart           # Individual message bubble (user/assistant)
    chat_input.dart               # Text input + send/stop button
    request_log_panel.dart        # Request/response log panel
```

- **`main.dart`** — App entry point. Initializes Hive, loads `.env`, creates `ChatRepository`, manages theme toggle.
- **`models/chat.dart`** — `Chat` and `ChatMessage` Hive models with hand-written TypeAdapters.
- **`services/api_service.dart`** — `ApiService` class. Sends streaming POST to `/v1/chat/completions`. Accepts `List<ChatMessage>` for multi-turn context. Parses SSE chunks. Supports cancellation.
- **`services/chat_repository.dart`** — `ChatRepository`. CRUD operations for chats and messages. Auto-generates chat titles from first message.
- **`screens/chat_screen.dart`** — Main UI. Message list with bubbles, chat input, adaptive sidebar (wide screens) or drawer (narrow). Settings and request log via bottom sheets.
- **`widgets/`** — Reusable UI components: `ChatDrawer`, `MessageBubble`, `ChatInput`, `RequestLogPanel`.

## Configuration

- API key is stored in `.env` file (root directory) as `API_KEY=...`, loaded via `flutter_dotenv`
- `.env` is bundled as a Flutter asset (declared in `pubspec.yaml`) and gitignored
- API base URL is hardcoded in `ApiService._baseUrl`
- Default model: `openai/gpt-4o-mini`, selectable from dropdown

## Key Dependencies

- `flutter_dotenv` — Environment variable loading
- `http` — HTTP client for streaming API requests
- `hive` / `hive_flutter` — Lightweight NoSQL DB for chat persistence
- `uuid` — Unique ID generation for chats and messages
- `path_provider` — File system paths for Hive storage

## Target Platforms

Android, Windows, Web (platform runners exist in project)
