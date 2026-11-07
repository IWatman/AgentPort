# AgentPort — Development Plan

Repository: https://github.com/IWatman/AgentPort  
Package: `com.iwatman.agentport`  
MVP platform: Android. Windows after MVP.  
License: MIT.  
UI languages: English and Russian.  
Repository documentation, README, release notes, and commit messages: English.

---

## 1. Product

AgentPort is an Android AI chat app with a built-in MCP marketplace and remote control for OpenCode.

Features:

- DeepSeek and any OpenAI-compatible API with a user-supplied key.
- Browse and install ready-made MCP connectors from plugin marketplaces.
- Default marketplace: `anthropics/claude-plugins-official`.
- Add compatible marketplaces by `owner/repo`, GitHub URL, or direct `marketplace.json` URL.
- One-click authorization for remote MCP servers that support OAuth.
- OpenCode pairing via QR code (`opencode pair`).
- Local encrypted storage for chats, keys, and tokens.
- Updates from GitHub Releases: stable channel, automatic check with a popup.

No Google Cloud project, no per-user `client_id`, no native Google OAuth implementation. Google Calendar, Gmail, Notion, GitHub, and similar services are connected through MCP plugins from the marketplace.

---

## 2. Key Decisions

| Area | Decision |
|---|---|
| UI | Flutter, Material 3, dark theme, English + Russian localization |
| State | Riverpod |
| Navigation | go_router |
| Database | Drift + SQLCipher |
| Secrets | flutter_secure_storage → Android Keystore |
| HTTP | dio |
| Streaming | SSE / chunked HTTP |
| MCP | Custom JSON-RPC 2.0 client: Streamable HTTP + SSE fallback |
| MCP auth | OAuth 2.1 + PKCE + dynamic client registration, API key, or no auth |
| Marketplace | Claude plugin marketplace format (`marketplace.json` + `.mcp.json`) |
| OpenCode | REST + SSE, Basic auth, OpenCode 2.2.5+ |
| Updates | GitHub Releases API (stable only) + PackageInstaller |
| CI | GitHub Actions |
| minSdk | 26 (Android 8.0) |
| targetSdk | 36 |

---

## 3. MVP Scope

### Included

- Chat with DeepSeek and a custom OpenAI-compatible provider.
- Chat history, streaming, stop, retry.
- MCP marketplace: browse, search, plugin details, install.
- Plugin manager with Plugins and Marketplaces tabs.
- Default Claude plugins marketplace and custom marketplace URLs.
- Add marketplace by `owner/repo`, GitHub URL, or direct `marketplace.json` URL.
- Enable/disable, refresh, and delete installed plugins.
- Install remote MCP servers from plugins.
- MCP OAuth authorization in the browser.
- MCP API-key and header-based authorization.
- MCP tools in chat with per-tool enable/disable and approvals.
- OpenCode: QR pairing, session list, open session, prompt, streaming, stop, switch agent/model.
- Settings, encryption, export/import without secrets.
- Updates: stable channel, automatic check, popup, download, install.
- GitHub Actions: APK build, checksums, release.

### Not Included in MVP

- Native Google OAuth.
- Per-user Google Cloud setup.
- Running stdio MCP servers on Android (`npx`, local binaries).
- Plugin commands, agents, hooks, and skills. MCP servers only.
- Gmail-specific native integration.
- OpenCode approvals, files, diff, terminal, git.
- Windows client.
- Cross-device sync.
- Play Store release.

---

## 4. Architecture

```
lib/
  app/                 # bootstrap, router, theme, DI
  core/                # crypto, http, sse, errors, logging, version
  data/                # db, repositories, secure storage, migrations
  domain/              # entities, use cases, provider interfaces
  features/
    chat/              # conversations, messages, composer, streaming
    providers/         # deepseek, openai-compatible, model settings
    marketplace/       # catalog, search, plugin details, install
    mcp/               # client, registry, tools, approvals, oauth
    opencode/          # pairing, rest client, sse, sessions
    settings/          # providers, connections, about, updates
    updates/           # github releases, downloader, installer
```

Layers:

- `presentation` — widgets and controllers.
- `domain` — entities and use cases.
- `data` — APIs, database, secure storage.

Rule: UI does not know about HTTP or the database. Secrets never enter domain models in plaintext — only secure-storage references.

---

## 5. Data Model

| Table | Fields |
|---|---|
| `providers` | id, name, type, base_url, model, api_key_ref, created_at |
| `conversations` | id, title, provider_id, system_prompt, archived, created_at, updated_at |
| `messages` | id, conversation_id, role, content, reasoning, tool_calls_json, status, created_at |
| `tool_calls` | id, message_id, server_id, tool_name, arguments_json, result_json, status, created_at |
| `marketplaces` | id, name, url, last_sync_at, etag, enabled |
| `marketplace_plugins` | id, marketplace_id, slug, name, description, author, category, homepage, source_json, installed, enabled, scope, installed_version, update_available, last_error, last_seen_at |
| `mcp_servers` | id, plugin_id, name, url, transport, auth_type, headers_ref, oauth_ref, enabled, created_at |
| `mcp_tools` | id, server_id, name, description, schema_json, enabled, needs_approval |
| `oauth_sessions` | id, server_id, client_id, scopes, token_ref, expires_at |
| `opencode_connections` | id, name, url, username, token_ref, last_seen |
| `settings` | key, value |
| `update_state` | last_check_at, skipped_version |

Encryption:

- Random 256-bit database key → Android Keystore.
- API keys, OAuth access/refresh tokens, OpenCode token, MCP headers → Keystore.
- Only references/IDs are stored in the database.

---

## 6. Model Providers

Interface:

```dart
abstract class ChatProvider {
  Stream<ChatDelta> stream({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    required String model,
  });
}
```

Implementations:

1. **DeepSeek**
   - Base URL: `https://api.deepseek.com`.
   - OpenAI-compatible `/chat/completions`.
   - Streaming, `tools`, `tool_choice`.
   - `reasoning_content` rendered in a separate block.

2. **OpenAI-compatible**
   - User enters base URL, key, model.
   - Supports `/v1/chat/completions`.
   - "Test connection" button.

Tool-calling loop:

```
user → model → tool_call → MCP tool → tool_result → model → answer
```

Limits:

- Maximum 8 tool-loop iterations.
- Tool call timeout: 60 seconds.
- Maximum tool result size: 256 KB.
- Cancelling the stream cancels the current tool loop.

---

## 7. Marketplace

### 7.1. Default Source

```
https://github.com/anthropics/claude-plugins-official
```

Marketplace manifest:

```
https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json
```

The source is seeded as a built-in, non-deletable marketplace. The catalog is cached locally and refreshed on first use if the cache is older than 24 hours.

The app reads the Claude plugin marketplace schema:

```json
{
  "name": "claude-plugins-official",
  "plugins": [
    {
      "name": "context7",
      "description": "Up-to-date documentation lookup",
      "author": { "name": "Upstash" },
      "category": "development",
      "source": "./external_plugins/context7",
      "homepage": "https://github.com/anthropics/claude-plugins-official"
    }
  ]
}
```

### 7.2. Plugin Resolution

Supported `source` types:

1. **Relative path** — `./plugins/name` or `./external_plugins/name`.
2. **`git-subdir`** — GitHub repo URL + `path` + `ref`/`sha`.
3. **`url`** — GitHub repo root.

Resolution:

1. Resolve the plugin source to a raw-content base.
2. Fetch `.mcp.json` lazily when the plugin detail is opened or installation starts.
3. Parse `mcpServers`.
4. Show remote servers. Mark stdio-only plugins as unsupported on Android.

Example `.mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

### 7.3. Marketplace UI

The layout mirrors the Claude Desktop plugin manager.

Two tabs:

- **Plugins**
- **Marketplaces**

#### Plugins tab

Search field:

```
Search plugins...
```

Sections:

- **Installed**
- **Available**

Each plugin row:

- Green status dot when enabled.
- Name: `plugin-name@marketplace-name`.
- Scope label: `Scope: user`.
- Enable/disable toggle.
- Refresh icon.
- Delete icon.
- Inline warning when a plugin conflicts with another installed copy.

Plugin detail:

- Name, author, description, homepage.
- Marketplace name.
- MCP servers in the plugin.
- Auth type: OAuth, API key, none, unsupported.
- Remote/stdio badge.
- Install / uninstall.
- Version and update state.

#### Marketplaces tab

Add field:

```
owner/repo, GitHub URL, or marketplace.json URL...
```

- **Add** button.
- Accepts `owner/repo`, a full GitHub URL, or a direct `marketplace.json` URL.
- Marketplace row:
  - Name and icon.
  - `GitHub: owner/repo` link.
  - Refresh icon.
  - Delete icon.
- Deleting a marketplace removes its catalog and its installed plugins after confirmation.

#### Behavior

- Installation state is stored locally; refresh keeps installed plugins.
- Toggle enables/disables the plugin's MCP server.
- Delete uninstalls the plugin and removes its MCP server.
- Refresh checks for plugin updates and MCP URL changes.
- If a plugin changes its MCP URL, require re-consent before enabling.
- Search filters by name, description, author, and category.
- Trust labels:
  - Author Anthropic: Anthropic.
  - Other plugins in the official marketplace: Verified partner.
  - Custom marketplaces: Community / unverified.
- Marketplace tables store no secret values (OAuth tokens, API keys, or resolved header values); authorization is handled in Connections (M4).
- Empty state: "No marketplaces yet. Add the official Claude marketplace."

### 7.4. Limitations

- Android supports only remote HTTPS MCP servers (`http`, `streamable-http`, `sse`).
- `stdio` servers (`command`, `args`, `env`) are cataloged but cannot be installed on Android.
- Plugin commands, agents, hooks, and skills are ignored in MVP.
- Plugins that require a desktop setup script are marked "Desktop setup required".

---

## 8. MCP Client and Authorization

### 8.1. Transports

- Streamable HTTP (primary).
- SSE (fallback).

### 8.2. Lifecycle

1. `initialize`
2. `notifications/initialized`
3. `tools/list`
4. `tools/call`
5. `notifications/tools/list_changed`

### 8.3. OAuth

MCP servers may require OAuth 2.1:

1. Call the MCP endpoint without a token.
2. Read `WWW-Authenticate`.
3. Fetch protected resource metadata (`/.well-known/oauth-protected-resource`).
4. Fetch authorization server metadata (`/.well-known/oauth-authorization-server`).
5. Register the app dynamically (RFC 7591) to obtain a `client_id`.
6. Open the system browser with PKCE.
7. Receive the callback on `http://127.0.0.1:<port>/mcp/callback`.
8. Exchange the code for tokens.
9. Store tokens in the Keystore.
10. Refresh on 401 and retry once.

Fallbacks:

- Manual API key or bearer token.
- Manual custom headers.

No Google Cloud project and no per-service `client_id` for the user. If a marketplace plugin uses a provider-hosted OAuth proxy, the user only sees the provider's consent screen.

### 8.4. Tool Approvals

- Read-only tools — automatic.
- Write/destructive tools — `needs_approval = true` by default.
- Dialog: tool name, arguments, "Allow" / "Deny".
- Denial returns `permission denied` to the model.

### 8.5. Errors

- timeout
- 401/403
- invalid schema
- server disconnected
- tool execution error
- OAuth discovery failed
- OAuth registration failed

All errors are shown in the chat as a tool result so the model can recover.

---

## 9. OpenCode

### 9.1. Connection

On the computer:

```bash
opencode service set password 'strong-password'
opencode service start
opencode pair
```

Remote:

```bash
opencode pair --remote
```

Or a custom tunnel:

```bash
opencode pair --url https://your-host
```

### 9.2. QR Format

```json
{"code":"abc123","urls":["http://192.168.1.10:4096"]}
```

Or a link:

```
http://192.168.1.10:4096/auth/connect/abc123
```

Properties:

- The code is single-use.
- It expires after 5 minutes.
- The QR code contains only reachable addresses.
- `--remote` provides an external URL through OpenTunnel.

### 9.3. Redeem

```
GET /auth/connect/:code
Accept: application/json
```

Response:

```json
{"token":"..."}
```

The token is used as the Basic auth password:

- username: `opencode`
- password: token

### 9.4. MVP API

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/info` | version, URLs, capabilities |
| GET | `/api/session` | session list |
| GET | `/api/session/:id` | session details |
| POST | `/api/session/:id/prompt` | send prompt |
| POST | `/api/session/:id/interrupt` | stop |
| POST | `/api/session/:id/agent` | switch agent |
| POST | `/api/session/:id/model` | switch model |
| GET | `/api/event` | SSE event stream |

Minimum supported version: OpenCode 2.2.5.

### 9.5. UI

- Connection list.
- "Scan QR" button.
- Manual URL + password entry.
- Session list with project and timestamp.
- Session screen: messages, streaming, stop, agent/model selection.
- Connection indicator.

### 9.6. Limitations

- The OpenCode API v2 is experimental.
- Pin a minimum version in the README.
- Check `/api/info` on connect.
- Full remote control (approvals, files, diff, terminal, git) is phase 2.

---

## 10. Updates

### 10.1. Channel

Only one channel: **Stable**.

Source:

- GitHub Release where `draft == false` and `prerelease == false`.
- The latest such release is the update target.

No prerelease channel. No channel switch.

### 10.2. Versions

Tags:

- `v0.1.0`
- `v0.1.1`
- `v1.0.0`

`versionCode`:

```
major * 1_000_000 + minor * 10_000 + patch * 100
```

Examples:

- `v0.1.0` → `10000`
- `v0.1.1` → `10100`
- `v1.0.0` → `1000000`

CI checks:

- the tag matches SemVer;
- versionName matches the tag without `v`;
- versionCode increases monotonically.

### 10.3. Update Check

```
GET https://api.github.com/repos/IWatman/AgentPort/releases/latest
```

Filter:

- `draft == false`
- `prerelease == false`
- an APK asset exists
- a `checksums.txt` asset exists

Comparison uses SemVer, not versionCode.

Cache:

- `ETag` + `If-None-Match`.
- `last_check_at` no more than once every 24 hours.
- Manual check ignores throttling.

### 10.4. Automatic Check and Popup

On launch:

1. 2–3 seconds after the first frame.
2. If `auto_check == true`.
3. If more than 24 hours have passed since the last check.
4. If the version is not in `skipped_version`.

Popup:

- Version name.
- Date.
- APK size.
- Release notes.
- Buttons:
  - "Update"
  - "Later"
  - "Skip this version"

If no update is available, no popup is shown. A manual check shows "You are on the latest version".

### 10.5. Download and Install

1. Find the `agentport-<tag>.apk` asset.
2. Download with progress.
3. Download `checksums.txt`.
4. Verify SHA-256.
5. Launch `PackageInstaller`.

Android requirements:

- `REQUEST_INSTALL_PACKAGES`.
- FileProvider.
- The user allows installs from unknown sources.
- System install confirmation screen.

Protection:

- HTTPS only.
- Checksum is mandatory.
- Android verifies the APK signature: an update signed with a different key will not install.
- Release notes are sanitized.
- No silent installs.

Errors:

- no network;
- 403/404;
- rate limit;
- checksum mismatch;
- install cancelled;
- signature mismatch.

All errors are shown in clear language without crashing.

### 10.6. CI and Release

`.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ["v*"]
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release --build-name="${TAG#v}" --build-number="$VERSION_CODE"
      - run: sha256sum build/app/outputs/flutter-apk/app-release.apk > checksums.txt
      - run: gh release create "$TAG" build/app/outputs/flutter-apk/app-release.apk#agentport-"$TAG".apk checksums.txt --generate-notes
        env:
          GH_TOKEN: ${{ github.token }}
```

### 10.7. Signing Key

The release keystore is stored in GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Rules:

- One signing key for all releases.
- GitHub secrets are write-only: keep an offline backup of the JKS and passwords.
- Losing the key makes future updates impossible.
- The keystore is never committed to the repository.
- Releases are created from `main` only.

---

## 11. Security

- All secrets live only in the Keystore.
- The database uses SQLCipher.
- Logs never contain keys, tokens, or headers.
- OAuth uses PKCE and `state`.
- MCP OAuth tokens are encrypted.
- Marketplace content is untrusted: show author and trust label.
- Never execute `stdio` commands from plugins on Android.
- Remote MCP URLs must use HTTPS.
- Allow `http://localhost` and LAN addresses only after an explicit warning.
- Write tools require approval.
- OpenCode uses HTTPS or a private network; warn on HTTP.
- QR code is single-use and expires after 5 minutes.
- Warn if the device blocks installs from unknown sources.
- Chat export excludes keys and tokens.
- Consider `FLAG_SECURE` on screens that display secrets.

---

## 12. Screens

All UI strings live in ARB files. English is the default locale; Russian is available in settings.

1. Onboarding.
2. Chats.
3. Chat.
4. Providers.
5. Provider editor.
6. Marketplace manager — Plugins tab.
7. Marketplace manager — Marketplaces tab.
8. Marketplace search.
9. Plugin detail.
10. Add marketplace.
11. Installed connectors.
12. MCP server detail.
13. MCP tool list.
14. OAuth consent / browser handoff.
15. OpenCode connections.
16. OpenCode pair scanner.
17. OpenCode sessions.
18. OpenCode session.
19. Settings.
20. About / Updates.
21. Update dialog.
22. Update download/progress.

---

## 13. Milestones

Estimate for one developer, no designer.

### M0 — Bootstrap, 2 days

- Create the Flutter project.
- Package `com.iwatman.agentport`.
- Material 3 theme, router, Riverpod.
- English + Russian localization via ARB files.
- Repository docs, README, release notes, and commit messages in English.
- Drift + SQLCipher skeleton.
- Secure storage wrapper.
- CI: analyze + test.
- `docs/` and README.
- About screen with version.

Done: the app builds, opens, and shows its version.

### M1 — Chat and Providers, 4 days

- Provider CRUD.
- Presets for DeepSeek, OpenAI, OpenRouter, Groq, Mistral, Together AI, xAI, and Gemini.
- DeepSeek preset.
- Custom OpenAI-compatible.
- Streaming, stop, retry.
- Photo and text-file attachments, per-conversation model selection with human-readable names, voice input.
- History, rename/delete.
- Markdown and code blocks.
- Error handling.

Done: a full chat works with the user's key.

### M2 — MCP Core, 4 days

- MCP client (initialize, tools/list, tools/call).
- Streamable HTTP + SSE.
- Tool registry.
- Tool loop.
- Approval UI.
- Fake MCP server for tests.

Current status: Streamable HTTP client, tool discovery/cache, Connections UI, the chat tool loop, and the approval dialog are implemented. Tool calling is verified end-to-end against a public DeepWiki MCP server. Legacy SSE transport remains.

Done: the model invokes an external MCP tool.

### M3 — Marketplace, 4 days

- Marketplace manifest parser.
- Default Claude marketplace.
- Custom marketplace URLs.
- Plugin detail and source resolution.
- `.mcp.json` parser.
- Remote vs stdio detection.
- Install/uninstall.
- Trust labels.
- Catalog cache and refresh.
- Marketplace manager with **Plugins** and **Marketplaces** tabs.
- Search, Installed/Available sections.
- Plugin rows with status dot, `name@marketplace`, `Scope: user`, toggle, refresh, delete.
- Add marketplace field: `owner/repo`, GitHub URL, or direct `marketplace.json` URL.
- Conflict warning for duplicate plugin names.
- Marketplace rows with GitHub link, refresh, delete.

Done: a user browses the marketplace, installs a remote MCP plugin, and manages it with the same controls as Claude Desktop.

### M4 — MCP OAuth and Install Flow, 4 days

- OAuth discovery.
- Dynamic client registration.
- PKCE + loopback callback.
- Token storage and refresh.
- API key and manual header fallback.
- Re-consent when a plugin changes its MCP URL.
- Error states.

Current status: manual API key/header fallback, secure header storage, connection testing, and re-consent are implemented. Browser OAuth discovery and token refresh remain.

Done: a user installs a plugin, taps "Connect", logs in through the browser, and the tools work.

### M5 — OpenCode, 5 days

- QR scanner.
- Pairing payload parser.
- Code redemption.
- Basic auth.
- Session list.
- Session screen.
- Prompt + SSE.
- Stop.
- Agent/model.
- Manual URL entry.
- Minimum supported OpenCode version: 2.2.5.

Current status: complete. The OpenCode tab lives on the Chats screen. Pairing by QR or manual URL/password, connection storage, project list, sessions filtered by project, new-session creation, transcript with reasoning and tool chips, prompt streaming, stop, agent/model switching, and the 2.2.5 version check are implemented. Verified against OpenCode 2.2.6 over a local tunnel. Automatic reconnect after an idle SSE timeout is still manual.

Done: the phone controls an OpenCode session.

### M6 — Updates and Releases, 3 days

- GitHub Releases client.
- Stable channel only.
- Automatic check.
- Popup.
- Download + checksum.
- PackageInstaller.
- Release workflow.
- First `v0.1.0`.

Current status: complete except the first published release. The stable release client, semantic version checks, streaming downloader with SHA-256 verification, PackageInstaller bridge, signed GitHub release workflow, daily automatic check, Settings check, release-notes popup, download progress, and installer handoff are implemented. GitHub secrets must be configured before tagging `v0.1.0`.

Done: an older version sees the popup and updates.

### M7 — Polish, 3 days

- Tests.
- Security review.
- Onboarding.
- README, screenshots.
- Crash handling.
- Final testing on real devices.

Total: ~29 working days.

---

## 14. Testing

Unit:

- SemVer comparison.
- versionCode.
- Marketplace manifest parser.
- Plugin source resolver.
- `.mcp.json` parser.
- Pairing payload parser.
- MCP JSON-RPC.
- OAuth PKCE and state.
- Database migrations.

Widget:

- Chat composer.
- Marketplace cards.
- Plugin detail.
- Update dialog.
- Approval dialog.
- Provider form validation.

Integration:

- Fake MCP server with OAuth.
- Fake marketplace server.
- Fake OpenCode server.
- Fake GitHub Releases API.
- Download + checksum.

Manual:

- DeepSeek real key.
- OpenAI-compatible endpoint.
- Context7 plugin from the default marketplace.
- A plugin with OAuth.
- A stdio-only plugin is marked unsupported.
- OpenCode LAN + `--remote`.
- Android 8, 12, 14, 16.
- Installing an update over an older version.

CI:

- `flutter analyze`
- `flutter test`
- Debug APK build on PR.

---

## 15. Release Process

1. Update `CHANGELOG.md`.
2. Bump the version in `pubspec.yaml`.
3. Create a tag `v0.1.0` from `main`.
4. CI builds the APK, checksums, and publishes the Release.
5. Verify installation on a clean device.
6. Verify an update from the previous version.

Rollback:

- Publish a patch version.
- Never reuse tags.
- Keep old APKs in Releases.

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| Marketplace plugins change MCP URLs | show diff, require re-consent |
| Malicious marketplace plugin | trust labels, no stdio execution, approvals |
| MCP OAuth server lacks dynamic registration | manual token/header fallback |
| Android cannot run stdio MCP | filter and mark unsupported |
| OpenCode API v2 changes | pin version 2.2.5+, check `/api/info` |
| Google/Gmail not in marketplace | user installs a provider-hosted plugin |
| Immature Dart MCP libraries | custom thin JSON-RPC client |
| GitHub rate limit | ETag, cache, raw.githubusercontent.com |
| Signing key loss | offline backup, CI secrets |
| DeepSeek tool calling | tests, iteration limit, manual fallback |
| Terminal in phase 2 is dangerous | approvals, HTTPS/VPN, explicit warnings |

---

## 17. Phase 2

- Plugin commands, agents, hooks, and skills.
- OpenCode approvals from the phone.
- Files and diff.
- Git status/diff.
- Terminal.
- Worktrees.
- Notifications.
- Gmail-specific tools via marketplace.
- Windows client.
- Voice input.
- Widgets and quick actions.
- Play Store (if needed).

---

## 18. First Step

M0:

1. `flutter create` with package `com.iwatman.agentport`.
2. Configure theme, router, Riverpod.
3. Add English/Russian ARB localization.
4. Add Drift + SQLCipher.
5. Add secure storage.
6. Add CI.
7. Add README and docs.
8. Build the APK.
