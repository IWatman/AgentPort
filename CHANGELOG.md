# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-11-11

### Added

- Sign in with a ChatGPT account (OpenAI Responses API) or an OpenRouter account instead of an API key where the provider officially supports it. Browser OAuth keeps credentials in the Android Keystore, pins official endpoints, and refreshes tokens automatically.
- An authentication-method selector in the provider editor, account sign-in status, and a model picker backed by the provider.

### Changed

- Providers store their authentication method, so account-based providers survive migrations, backups, and edits without exporting secrets.
- Backups keep the authentication method while continuing to omit API keys and OAuth tokens.

### Documentation

- Expanded the Google Workspace section with project-number registration in the Developer Preview Program, API/MCP service hosts, OAuth client requirements, scopes, per-service consent, and troubleshooting.

## [0.2.4] - 2026-11-10

### Fixed

- Bottom navigation labels no longer wrap or clip on narrow screens or with a large system font.
- The Connections tab label is now **Servers** / **Серверы**; its screen title remains **Connections** / **Подключения**.

## [0.2.3] - 2026-11-10

### Fixed

- Update downloads now run through Android's DownloadManager and continue with the screen off or the app in the background. Pending download state is restored after a restart.
- The update dialog explains that you can switch apps or turn off the screen while downloading.

### Changed

- Update progress and completion come from DownloadManager; the SHA-256 checksum is still verified before installation.

## [0.2.2] - 2026-11-09

### Fixed

- AI chat replies keep generating when you leave the chat screen and return later; the completed answer is saved to the conversation.

## [0.2.1] - 2026-11-09

### Added

- Google Workspace MCP presets for Calendar, Gmail, Drive, Docs, Sheets, Slides, Chat, People, and Classroom.
- Pre-registered OAuth client support with a fixed loopback redirect, custom scopes, `access_type=offline`, and `prompt=consent`.
- Google Workspace setup screen with a copyable redirect URI and an in-app setup guide.
- Background plugin compatibility checks for Android; unsupported plugins are hidden from the Plugins tab.
- OpenCode session search across projects by title, directory, or session ID.

### Changed

- MCP OAuth client secrets are stored in the Android Keystore alongside tokens.

## [0.2.0] - 2026-11-09

### Added

- OpenCode project creation with a remote folder browser backed by `GET /api/fs/list`; no manual host paths.
- OpenCode session context sheet with current context usage, model limit, token breakdown, cache usage, cost (including subagents), timestamps, message counts, and the latest system prompt.
- OpenCode extensions sheet with MCP server status, plugin counts, and searchable skills; LSP is documented as not exposed by the API.
- MCP server switches in the extensions sheet: connect and disconnect servers through the OpenCode API, with live status refresh.
- OpenCode permission requests now appear in the session with **Allow once**, **Always allow**, and **Deny** replies.
- `docs/OPENCODE.md` with the implemented/available OpenCode capability matrix.

### Fixed

- Session context now reports current context tokens from the latest assistant message instead of cumulative cache reads, and refreshes session cost when the sheet opens.

## [0.1.1] - 2026-11-08

### Added

- MCP legacy HTTP+SSE transport: incremental SSE parsing, endpoint origin checks, per-request response routing, timeouts, and cleanup, alongside Streamable HTTP.
- README screenshots and a Phase 1 security review with a verification checklist in `docs/SECURITY.md`.

### Changed

- OpenCode transcripts now group a whole assistant reply into one turn: reasoning stays hidden behind a psychology button, tool calls collapse into a single "Used N" summary, and only the final answer is shown.
- The scroll-to-bottom button now jumps to the real end of the list in one tap in AI and OpenCode chats, including lazily built lists and streaming content.
- Release builds show a neutral error screen for uncaught widget errors, and plain HTTP OpenCode URLs show an unencrypted-connection warning.

## [0.1.0] - 2026-11-08

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
- Data backup: export chats and providers to JSON without API keys or tokens, and import them back from Settings.
- Polish: reasoning is collapsed by default in AI and OpenCode chats, release builds show a neutral error screen for uncaught widget errors, and plain HTTP OpenCode URLs show an unencrypted-connection warning.
