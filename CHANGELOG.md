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
- OpenCode pairing and API client: payload/link parsing, code redemption, Basic auth, sessions, prompts, stop, agent/model switching, SSE events, and the 2.2.5 version check.
- OpenCode remote control UI: a dedicated OpenCode tab on Chats, connection list, QR scanner and manual URL/password pairing, project list, sessions filtered by project, new-session creation, transcript with reasoning and tool chips, live event indicator, prompt composer with stop, and agent/model pickers.
- OpenCode transcripts load up to 200 messages in chronological order and render image and file attachments on user messages.
- Update infrastructure: stable-only GitHub Releases client, semantic version checks, streaming APK downloader with SHA-256 verification, Android PackageInstaller/FileProvider bridge, and a tag-driven signed release workflow with checksums.
- In-app updates: daily automatic check, manual check in Settings, release-notes popup, download progress, checksum verification, install-permission guidance, and the system installer handoff.
