# AgentPort

**Android AI chat client with MCP connectors and remote control for [OpenCode](https://opencode.ai).**

[![CI](https://github.com/IWatman/AgentPort/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/IWatman/AgentPort/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/IWatman/AgentPort?display_name=tag&sort=semver)](https://github.com/IWatman/AgentPort/releases/latest)
[![License: MIT](https://img.shields.io/github/license/IWatman/AgentPort)](LICENSE)
![Android 8.0+](https://img.shields.io/badge/Android-8.0%2B-3DDC84?logo=android&logoColor=white)

AgentPort is a local-first Android app for chatting with AI models using your own API key, connecting remote MCP servers, and controlling OpenCode sessions from your phone.

> **Status:** `v0.3.0` is the latest stable release.

## Contents

- [Screenshots](#screenshots)
- [Features](#features)
- [Install](#install)
- [OpenCode](#opencode)
- [MCP marketplace](#mcp-marketplace)
  - [Google Workspace](#google-workspace)
- [Providers](#providers)
- [Security and privacy](#security-and-privacy)
- [Build from source](#build-from-source)
- [Tech stack](#tech-stack)
- [Releases](#releases)
- [Documentation](#documentation)
- [Limitations](#limitations)
- [Contributing](#contributing)
- [License](#license)

## Screenshots

<p align="center">
  <img src="docs/screenshots/chats.png" width="24%" alt="Chats and OpenCode">
  <img src="docs/screenshots/chat.png" width="46%" alt="Collapsed reasoning and streamed answer">
  <img src="docs/screenshots/plugins.png" width="24%" alt="Plugin marketplace">
</p>
<p align="center">
  <img src="docs/screenshots/connections.png" width="24%" alt="MCP connections">
  <img src="docs/screenshots/settings.png" width="24%" alt="Settings">
</p>

## Features

### Chat

- DeepSeek and any OpenAI-compatible API with your own key.
- Sign in with a ChatGPT account or an OpenRouter account instead of pasting a key where the provider supports it; tokens stay in the Android Keystore.
- Presets for DeepSeek, OpenAI, OpenRouter, Groq, Mistral, Together AI, xAI, and Google Gemini.
- Streaming replies, stop and retry, Markdown and code blocks.
- Replies keep generating while you browse other screens; return to the chat to see the finished answer.
- Photos, text-file attachments, voice input, and per-conversation model selection.
- Reasoning cards stay collapsed by default.
- One-tap scroll to the true bottom of a long transcript.

### MCP connectors

- Browse Claude-compatible plugin marketplaces and install remote MCP servers.
- Google Workspace presets for Calendar, Gmail, Drive, Docs, Sheets, Slides, Chat, People, and Classroom; paste one Google Cloud OAuth client and select the services you need.
- Streamable HTTP and legacy HTTP+SSE transports over HTTPS.
- Browser OAuth with discovery, dynamic registration, Authorization Code + PKCE, a loopback callback, and automatic token refresh.
- Pre-registered OAuth clients with fixed redirect URIs, custom scopes, and extra authorization parameters for providers such as Google.
- Manual API key or header authorization as a fallback.
- Tool calls in chat: read-only tools run automatically, write tools ask for approval, and a turn is capped at four tool rounds.

### OpenCode remote control

- Pair by QR code or URL; connect over LAN, a tunnel, or a remote host.
- Browse projects, create a project with a remote folder browser, and list only that project's sessions; search all sessions by title, directory, or ID.
- Grouped transcripts: hidden reasoning behind a psychology button, one **Used N** tool summary, then the final answer.
- Slash commands, `@` project-file mentions, image and file attachments.
- Agent, model, and model-variant switching; token, cost, and context details.
- Session context sheet with current context usage, session totals, cost including subagents, timestamps, message counts, and the latest system prompt.
- Extensions sheet with MCP server status and connect/disconnect switches, plugins, and searchable skills.
- OpenCode permission prompts can be answered from the phone with allow-once, always-allow, or deny.
- Live SSE updates, automatic reconnect, and refresh when another client changes the session.

### Data and updates

- SQLCipher-encrypted chats and local data.
- API keys and tokens in the Android Keystore, never in the database.
- Export and import chats/providers without secrets.
- Daily and on-demand stable update checks with release notes, download progress, SHA-256 verification, and the Android installer.
- Update downloads run through Android's DownloadManager, so they continue with the screen off or the app in the background and resume after a restart.
- English and Russian UI.

## Install

1. Download the latest APK from [GitHub Releases](https://github.com/IWatman/AgentPort/releases/latest).
2. Verify the SHA-256 checksum if needed.
3. Allow installation from your browser or file manager on Android.
4. Open AgentPort and complete onboarding.

Requirements: **Android 8.0 (API 26) or newer**. Releases from GitHub are signed with the project release key; future updates must use the same signature.

## OpenCode

On the computer:

```bash
opencode service set password 'strong-password'
opencode service start
opencode pair
```

In AgentPort, open **Chats → OpenCode → Pair**. Scan the QR code or enter the server URL and password manually. For a remote connection, use `opencode pair --remote` or pass a custom URL:

```bash
opencode pair --url https://your-host
```

After pairing, open the connection to browse projects and sessions. Use **New project** to browse folders on the OpenCode host and register one as a project. The session screen streams live output and supports prompts, stop, commands, mentions, agent/model switching, session context, and extensions.

Minimum supported OpenCode version: **2.2.5**. The OpenCode v2 API is experimental. See [docs/OPENCODE.md](docs/OPENCODE.md) for the full support matrix and remaining API capabilities.

## MCP marketplace

The official Anthropic marketplace, `anthropics/claude-plugins-official`, is seeded on first launch and cannot be deleted. Its catalog is cached locally after the first sync and refreshed on first use if the cache is older than 24 hours. Custom marketplace catalogs are cached too.

The Marketplace screen has two tabs:

- **Plugins** — search and filter by **All**, **MCP available**, or **Installed**.
- **Marketplaces** — refresh sources or add one with `owner/repo`, a GitHub URL, or a direct `marketplace.json` URL.

GitHub marketplaces keep their manifest at `.claude-plugin/marketplace.json`. After a catalog sync, AgentPort checks each plugin's `.mcp.json` in the background and caches the result.

Only remote MCP servers over HTTPS are supported on Android. The Plugins tab hides plugins that cannot run on a phone: local `stdio`/command servers, plugins without a remote MCP server, and plugins with an unresolved or failed compatibility check. Installed plugins stay visible so they can be managed or removed. Install state is stored locally; if a plugin's MCP configuration changes, it is disabled until the new configuration is reviewed and accepted.

### Google Workspace

AgentPort ships presets for the nine official Google Workspace remote MCP servers:

| Service | Google API to enable | MCP service to enable |
| --- | --- | --- |
| Calendar | `calendar-json.googleapis.com` | `calendarmcp.googleapis.com` |
| Gmail | `gmail.googleapis.com` | `gmailmcp.googleapis.com` |
| Drive | `drive.googleapis.com` | `drivemcp.googleapis.com` |
| Docs | `docs.googleapis.com` | `docsmcp.googleapis.com` |
| Sheets | `sheets.googleapis.com` | `sheetsmcp.googleapis.com` |
| Slides | `slides.googleapis.com` | `slidesmcp.googleapis.com` |
| Chat | `chat.googleapis.com` | `chatmcp.googleapis.com` |
| People | `people.googleapis.com` | `people.googleapis.com` |
| Classroom | `classroom.googleapis.com` | `classroommcp.googleapis.com` |

Google Workspace MCP is in **Developer Preview**. Three separate things must be configured; doing one does not enable the others:

1. **Developer Preview Program registration.** Join the [Google Workspace Developer Preview Program](https://developers.google.com/workspace/preview) with a Google Workspace account and register the exact Google Cloud **project number** (not the project ID). If the account is already a member, use the program's "add or remove a Google Cloud project" form. Google verifies this manually; it can take a few days. Until the project is registered, the MCP tool returns `Access to this tool requires that your Google Cloud project (<number>) is enrolled in the Google Workspace Developer Preview Program`.
2. **APIs in that project.** Enable the product API and the matching MCP service in the same project as the OAuth client. If an MCP service is not listed in the API Library, enable it with `gcloud services enable <service>`.
3. **OAuth client.** Create a **Web application** client (the official Workspace MCP path) or a **Desktop app** client. For a Web application client, add the exact redirect URI `http://127.0.0.1:53682/callback`. Select **Use this client for an AI-powered agent**. Since **11 November 2026**, Google rejects Workspace MCP clients without this flag; on **12 November 2026** the flag locks on existing clients, so a client that was not marked must be replaced.

OAuth consent screen:

- **Internal** is the better choice for a single Workspace organization.
- **External + Testing** works for personal testing: add the Google account under **Audience → Test users**. Google may expire refresh tokens for testing apps after about seven days.
- Add scopes only for the services you selected. AgentPort requests them automatically; the exact list is shown in the app's setup guide.

<details>
<summary>Scopes requested by AgentPort</summary>

| Service | Scopes |
| --- | --- |
| Calendar | `https://www.googleapis.com/auth/calendar` |
| Gmail | `https://www.googleapis.com/auth/gmail.modify` |
| Drive | `https://www.googleapis.com/auth/drive` |
| Docs | `https://www.googleapis.com/auth/documents`, `https://www.googleapis.com/auth/drive.readonly` |
| Sheets | `https://www.googleapis.com/auth/spreadsheets`, `https://www.googleapis.com/auth/drive.readonly` |
| Slides | `https://www.googleapis.com/auth/presentations`, `https://www.googleapis.com/auth/drive.readonly` |
| Chat | `https://www.googleapis.com/auth/chat.spaces`, `https://www.googleapis.com/auth/chat.messages`, `https://www.googleapis.com/auth/chat.memberships.readonly` |
| People | `https://www.googleapis.com/auth/contacts.readonly`, `https://www.googleapis.com/auth/directory.readonly`, `https://www.googleapis.com/auth/userinfo.profile` |
| Classroom | `https://www.googleapis.com/auth/classroom.courses`, `https://www.googleapis.com/auth/classroom.coursework.me`, `https://www.googleapis.com/auth/classroom.coursework.students`, `https://www.googleapis.com/auth/classroom.rosters.readonly`, `https://www.googleapis.com/auth/classroom.announcements.readonly`, `https://www.googleapis.com/auth/classroom.topics.readonly`, `https://www.googleapis.com/auth/classroom.profile.emails` |

</details>

In AgentPort, open **Connections → Add Google Workspace**, paste the client ID and secret, select services, and tap **Add selected**. Open each created server and tap **Connect with Google**. Every service creates its own MCP connection and token, so consent is requested separately for each one — each MCP endpoint is a separate OAuth resource. The OAuth client secret and tokens are stored only in the Android Keystore.

Common errors:

| Error | Cause and fix |
| --- | --- |
| `OAuth client was not found` | Wrong client type (Android/iOS instead of Web/Desktop), a mistyped or deleted client ID, or the ID and secret swapped. Create a **Web application** client in the same project and paste it again into every Google service. |
| `Access to this tool requires ... project ... enrolled` | The project number is not registered in the Developer Preview Program. Use the program application or the existing-member project form. There is no Cloud Console toggle. |
| `redirect_uri_mismatch` | The Web application client must contain exactly `http://127.0.0.1:53682/callback` (not `localhost`, no trailing slash). Google can take a few minutes to apply the change. |
| `access_denied` | The account is not a test user, the wrong Google account was used, or the consent screen is not configured. |
| `403` or the MCP server rejects the client | **Use this client for an AI-powered agent** is not selected, or the APIs/MCP services are enabled in a different project than the OAuth client. |
| `Port 53682 is busy` | Another app is using the loopback port. Close it and retry. |
| Workspace admin blocks access | Allow the OAuth app/API in the Admin console under **Security → API controls → App access control**. |

See the [official Google Workspace MCP setup guide](https://developers.google.com/workspace/guides/configure-mcp-servers) for the current Google-side requirements.

Trust labels:

- Author Anthropic: **Anthropic**.
- Other plugins in the official marketplace: **Verified partner**.
- Plugins from custom marketplaces: **Community / unverified**.

## Providers

Add a provider in **Settings → AI providers**. Presets fill the name and base URL for common OpenAI-compatible services; every field remains editable. The model is selected per conversation from the composer. Provider API keys are written to the Android Keystore and only a lookup reference is stored in the database.

## Security and privacy

- API keys, MCP header values, OAuth client IDs/secrets, OAuth tokens, and the OpenCode pairing token live in the Android Keystore.
- Chats and messages are stored in a SQLCipher-encrypted database.
- Backups exclude API keys, tokens, MCP credentials, and OpenCode connections.
- MCP OAuth uses PKCE and `state`; the loopback callback listens only on `127.0.0.1`. Google connections use the fixed `http://127.0.0.1:53682/callback` redirect.
- Remote MCP URLs must use HTTPS. Plain HTTP is accepted for OpenCode only with an explicit unencrypted-connection warning.
- Updates are stable-only, checksum-verified, and installed through Android's package installer. The APK is downloaded by the system DownloadManager into the app-specific external storage and verified before installation.

Read [docs/SECURITY.md](docs/SECURITY.md) for the Phase 1 security review, verification checklist, and residual risks. See [docs/PRIVACY.md](docs/PRIVACY.md) for the privacy policy.

## Build from source

Requirements:

- Flutter stable **3.47+**
- JDK **21**
- Android SDK **36**

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Local release builds use `android/key.properties` when present; otherwise they fall back to debug signing for local testing. CI uses the release signing secrets. See [docs/RELEASING.md](docs/RELEASING.md) for signing setup and versioning.

## Tech stack

| Area | Choice |
|---|---|
| UI | Flutter, Material 3, dark theme, English + Russian localization |
| State | Riverpod |
| Navigation | go_router |
| Database | Drift + SQLCipher |
| Secrets | flutter_secure_storage (Android Keystore) |
| HTTP / streaming | `http`, SSE |
| MCP | Custom JSON-RPC 2.0 client, Streamable HTTP + legacy HTTP+SSE |
| OpenCode | REST + SSE, Basic auth, OpenCode 2.2.5+ |
| Updates | GitHub Releases, SHA-256 verification, PackageInstaller |
| CI | GitHub Actions |

## Releases

Releases are cut from `main` by pushing a `vX.Y.Z` tag. CI builds and signs a universal APK, publishes SHA-256 checksums, and creates a stable GitHub Release. See [docs/RELEASING.md](docs/RELEASING.md).

The app checks for stable updates once per day when automatic checks are enabled, or on demand from **Settings → Check for updates**. A newer release opens a popup with its notes; the APK is downloaded with progress, verified against the published checksum, and handed to Android's installer.

## Documentation

| Document | Contents |
|---|---|
| [docs/OPENCODE.md](docs/OPENCODE.md) | OpenCode feature matrix: implemented, available, and deferred |
| [docs/SECURITY.md](docs/SECURITY.md) | Security review, checklist, and residual risks |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Privacy policy |
| [docs/RELEASING.md](docs/RELEASING.md) | Signing, versioning, and release process |
| [PLAN.md](PLAN.md) | Product plan and milestones |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## Limitations

- Android only for now; a Windows client is planned after the MVP.
- Remote MCP servers only on Android; local `stdio` servers cannot run inside the app.
- Google Workspace MCP servers are in Developer Preview: the Google Cloud **project** must be registered in the Workspace Developer Preview Program, the product APIs and `*mcp.googleapis.com` services must be enabled, and the OAuth client must be marked **Use this client for an AI-powered agent**.
- The OpenCode v2 API is experimental and may change between versions.
- OpenCode does not expose LSP status through its API, so AgentPort cannot list language servers.
- OpenCode terminal, file browser, diff/VCS, worktrees, and session fork/move/compact/revert are not implemented yet; they are tracked in [docs/OPENCODE.md](docs/OPENCODE.md).

## Contributing

Issues and pull requests are welcome. Before submitting a change, run:

```bash
flutter analyze
flutter test
```

Keep user-facing strings in `lib/l10n/app_en.arb` and `lib/l10n/app_ru.arb`, and add tests for new behavior.

## License

[MIT](LICENSE)
