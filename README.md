# AgentPort

Android AI chat client with a built-in MCP marketplace and remote control for [OpenCode](https://opencode.ai).

> Status: early development. MVP is not released yet.

## Features

- Chat with DeepSeek and any OpenAI-compatible API using your own key.
- Browse MCP connectors from Claude-compatible plugin marketplaces.
- Install remote MCP servers with one-click OAuth, API key, or custom headers.
- Control OpenCode sessions from your phone: pair by QR, send prompts, stream responses, stop, switch agent/model.
- Local encrypted storage for chats, keys, and tokens.
- Updates from GitHub Releases (stable channel).
- English and Russian UI.

## Platform

- MVP: Android 8.0+ (API 26).
- Windows: planned after MVP.

Remote MCP servers only (`http`, `sse`, `streamable-http`). Plugins that require local `stdio` commands are marked as unsupported on Android.

## Build

Requirements:

- Flutter stable 3.47+
- JDK 21
- Android SDK 36

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Release builds are signed by CI. Local release builds use `android/key.properties` if present.

## Connect OpenCode

On the computer:

```bash
opencode service set password 'strong-password'
opencode service start
opencode pair
```

Scan the QR code in AgentPort. For a remote connection use `opencode pair --remote`, or pass a custom URL with `opencode pair --url https://your-host`.

Minimum supported OpenCode version: **2.2.5**. The OpenCode API v2 is experimental.

## Documentation

- [Development plan](PLAN.md)
- [Privacy policy](docs/PRIVACY.md)

## License

[MIT](LICENSE)
