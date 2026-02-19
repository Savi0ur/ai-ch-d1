# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter chat app that streams responses from an OpenAI-compatible API (GPT-4o-mini via a proxy at `openai.api.proxyapi.ru`). Single-screen UI with a text input, optional request settings (system prompt, max tokens, stop sequence), and a streaming response view.

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

Two-file app in `lib/`:

- **`main.dart`** — App entry point, `ChatScreen` stateful widget. Loads `.env` at startup. Manages UI state: input view vs streaming result view (toggled by `_hasResponse`). Handles stream subscription lifecycle (listen/cancel/dispose).
- **`api_service.dart`** — `ApiService` class. Sends streaming POST requests to `/v1/chat/completions` using `http` package. Parses SSE chunks manually (buffered line splitting, `data: ` prefix extraction). Exposes `Stream<String>` of content deltas. Supports cancellation via `http.Client.close()`.

## Configuration

- API key is stored in `.env` file (root directory) as `API_KEY=...`, loaded via `flutter_dotenv`
- `.env` is bundled as a Flutter asset (declared in `pubspec.yaml`) and gitignored
- API base URL is hardcoded in `ApiService._baseUrl`
- Model is hardcoded as `openai/gpt-4o-mini` in the request body

## Key Dependencies

- `flutter_dotenv` — Environment variable loading
- `http` — HTTP client for streaming API requests

## Target Platforms

Android, Windows, Web (platform runners exist in project)
