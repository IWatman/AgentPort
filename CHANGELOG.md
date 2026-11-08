# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project bootstrap: Flutter app shell, theming, routing, localization, encrypted storage.
- AI providers with Keystore-backed API keys, streaming chat, stop/retry, and conversation history.
- Built-in `anthropics/claude-plugins-official` marketplace, custom marketplace sources, plugin search, install, refresh, and re-consent.
- MCP Connections: installed server list, Streamable HTTP handshake, tool discovery and cache, test connection, enable/disable, and Keystore-backed header authorization.
- Chat composer: photo and text-file attachments, per-conversation model selection, and voice input.
- Provider presets for DeepSeek, OpenAI, OpenRouter, Groq, Mistral, Together AI, xAI, and Google Gemini.
- MCP tools in chat: read-only tools run automatically, write tools ask for approval, tool errors are returned to the model, and the loop is capped at four rounds.
- MCP browser OAuth: protected-resource and authorization-server discovery, dynamic client registration, Authorization Code + PKCE with a loopback callback, Keystore-backed tokens, automatic refresh, and bearer authorization for MCP requests.
- OpenCode pairing and API client: payload/link parsing, code redemption, Basic auth, sessions, prompts, stop, agent/model switching, SSE events, and the 2.2.5 version check.
- OpenCode remote control UI: a dedicated OpenCode tab on Chats, connection list, QR scanner and manual URL/password pairing, project list, sessions filtered by project, new-session creation, transcript with reasoning and tool chips, live event indicator, prompt composer with stop, and agent/model pickers.
- OpenCode transcripts load up to 800 messages in chronological order, render image and file attachments on user messages, refresh when another client sends a prompt, and reconnect the event stream with backoff.
- Mobile OpenCode chat parity: slash-command picker and execution, `@` project file mentions with search, model variant selection, session rename/delete/info, token and cost details, and location-scoped command/model/agent lists.
- Scroll-to-bottom button in AI and OpenCode chats; auto-scroll pauses while reading history.
- Update infrastructure: stable-only GitHub Releases client, semantic version checks, streaming APK downloader with SHA-256 verification, Android PackageInstaller/FileProvider bridge, and a tag-driven signed release workflow with checksums.
- In-app updates: daily automatic check, manual check in Settings, release-notes popup, download progress, checksum verification, install-permission guidance, and the system installer handoff.
