# Flutter Local LLM Chat

A minimal chat app for talking to a local llama.cpp (OpenAI-compatible) server. Supports multiple sessions, dark purple theme, configurable settings, and local persistence.

## Requirements
- Flutter 3.32.x (Dart 3.8.x)
- A local LLM server exposing OpenAI-compatible `POST /v1/chat/completions` (e.g., llama.cpp server)

## Running
- Linux desktop (recommended during development):
```bash
cd llm_interface
flutter run -d linux
```
- Web (ensure CORS on your server):
```bash
flutter run -d chrome
```

## Settings (via header cog)
- Server URL: Base endpoint (default `http://127.0.0.1:8008`)
- Model: Optional; leave blank to use server default
- Temperature: Response randomness (default 0.7)
- Max tokens: Reply length cap (default 1014)
- Max history messages: Count cap for messages sent
- Max history chars (0 = disabled): Char cap for messages sent; set 0 to disable
- Keep head messages: Always include the first N messages (e.g., role/instructions)
- Streaming/Summarization: Toggles (UI available; streaming/summarization wiring planned)

## Features
- Multiple chat sessions with local storage (shared_preferences)
- New chat, rename, delete session
- Delete individual messages from a conversation
- Keyboard: Ctrl/Cmd+Enter to send, Shift+Enter for newline
- Dark purple theme matching your portfolio’s palette

## Behavior and Context
- On send, the app builds the request as:
  - First `keepHeadCount` messages (for system/character setup)
  - Then the most recent messages up to `maxHistoryMessages`
  - If `maxHistoryChars` > 0, it also trims by total characters while preserving the newest messages
  - If the head alone exceeds char cap, a few recent tail messages are still sent for fresh context
- Set `Max history chars` to 0 to disable char-based trimming entirely

## Troubleshooting
- Linux Wayland debug keyboard warnings can appear in dev; they’re harmless. Use X11 or release mode:
```bash
GDK_BACKEND=x11 flutter run -d linux
# or
flutter run -d linux --release
```
- Web requires permissive CORS headers from your server
- 400 errors from the server usually indicate payload or context limits; reduce caps or tokens

## Expected API
The server should accept an OpenAI-compatible body like:
```json
{
  "messages": [{"role": "user", "content": "Hello"}],
  "temperature": 0.7,
  "max_tokens": 1014,
  "stream": false
}
```
Endpoint: `POST /v1/chat/completions`

## Build
- Linux release:
```bash
flutter build linux --release
```
- Web release:
```bash
flutter build web --release
```
