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
