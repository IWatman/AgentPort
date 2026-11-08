# AgentPort

Android AI chat client with a built-in MCP marketplace and remote control for [OpenCode](https://opencode.ai).

> Status: MVP **0.1.0** is available from [GitHub Releases](https://github.com/IWatman/AgentPort/releases).

## Features

- Chat with DeepSeek and any OpenAI-compatible API using your own key.
- Ready-made presets for DeepSeek, OpenAI, OpenRouter, Groq, Mistral, Together AI, xAI, and Google Gemini.
- Attach photos and text files, switch models per conversation, and use voice input.
- Browse MCP connectors from Claude-compatible plugin marketplaces.
- Install remote MCP servers from marketplace plugins and configure header authorization in Connections.
- Let the model call MCP tools from chat, with automatic read-only calls and approval for write tools.
- Control OpenCode sessions from your phone: pair by QR or URL, read grouped transcripts with hidden reasoning and one-line tool summaries, send prompts, stream replies, stop, and switch agent/model.
- Local encrypted storage for chats, keys, and tokens.
- Export chats and providers to a JSON backup without secrets, and import them back from Settings.
- Automatic stable-channel update checks with a popup, release notes, progress, checksum verification, and the Android installer.
- English and Russian UI.

## Platform

- MVP: Android 8.0+ (API 26).
- Windows: planned after MVP.

Remote MCP servers only, over HTTPS (`http`, `streamable-http`, `sse`). Streamable HTTP is implemented; legacy SSE transport is listed but not connected yet. Plugins that require local `stdio` commands are shown but cannot be installed on Android.

## Chat

- Add a provider in Settings. Presets fill the name and base URL for common OpenAI-compatible services; every field remains editable. The model is chosen inside each chat.
- Use **+** in the composer to attach a photo or a text file. Attachments are stored in the encrypted database with the message.
- Tap the model bar under the composer to choose a model for this conversation. DeepSeek models are shown as **DeepSeek V4.1 Flash** and **DeepSeek V4 Pro**.
- Use the microphone button for device speech recognition; recognized text is inserted into the composer.
- When an MCP server has cached tools, the model can call them during a reply. Read-only tools run automatically; tools marked for approval show an **Allow / Deny** dialog. Denials and tool errors are returned to the model, and a turn stops after four tool rounds.

## Marketplace

The official Anthropic marketplace, `anthropics/claude-plugins-official`, is seeded on first launch and cannot be deleted. Its catalog (317 plugins at the time of writing) is cached locally after the first sync and refreshed on first use if the cache is older than 24 hours. Custom marketplace catalogs are also cached locally.

The Marketplace screen has two tabs:

- **Plugins** — search by name, description, author, or category; filter by **All**, **MCP available**, or **Installed**.
- **Marketplaces** — refresh sources, or add one with `owner/repo`, a GitHub URL, or a direct `marketplace.json` URL.

GitHub marketplaces keep their manifest at `.claude-plugin/marketplace.json`. A plugin's `.mcp.json` is fetched lazily when the plugin is opened, not during catalog sync.

Only remote MCP servers over HTTPS are supported on Android (`http`, `streamable-http`, and `sse`). Plugins that declare only `stdio`/`command` servers are listed but marked unsupported and cannot be installed.

Install state is stored locally. Refreshing a marketplace updates its catalog and keeps installed plugins. If a plugin's MCP configuration changes, the plugin is disabled until the new configuration is reviewed and accepted again.

Trust labels:

- Author Anthropic: **Anthropic**.
- Other plugins in the official marketplace: **Verified partner**.
- Plugins from custom marketplaces: **Community / unverified**.

Marketplace tables store no secret values (OAuth tokens, API keys, or resolved header values). MCP header values are stored separately in the Android Keystore. AgentPort uses no Google Cloud project and no per-user `client_id`.

### Install a plugin

1. Open **Marketplace** from the bottom navigation.
2. Search or filter the **Plugins** tab. The built-in official catalog loads on first use.
3. Open a plugin and review its trust label and MCP servers.
4. Tap **Install**. If the plugin has only local servers, it is marked unsupported and cannot be installed.
5. Use **Marketplaces** to add sources or refresh a catalog. Installed plugins are preserved.

## Connections

**Connections** lists the remote MCP servers installed from marketplace plugins.

- **Test connection** performs the MCP handshake, discovers tools, and caches them locally.
- Header values (API keys, bearer tokens) are stored in the Android Keystore, never in the database.
- Servers can be enabled or disabled without uninstalling the plugin.
- Tool details are shown with a read-only / requires-approval hint.

Current transport support: **Streamable HTTP over HTTPS**. Legacy SSE transport is listed but not connected yet. Servers that advertise protected-resource metadata can be authorized with **Connect with browser**: AgentPort discovers the authorization server, registers a client, completes Authorization Code + PKCE through a loopback callback, and stores/refreshes tokens in the Android Keystore. Manual API key or header authorization remains available as a fallback. Cached tools are available to the model in chat; tool calls stream through the same OpenAI-compatible request loop.

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

### Releases

Releases are cut from `main` by pushing a `vX.Y.Z` tag. GitHub Actions builds and signs the universal APK, publishes SHA-256 checksums, and creates a stable GitHub Release. See [Releasing](docs/RELEASING.md) for secrets, versioning, and checksum verification.

The app checks for stable updates once per day when automatic checks are enabled, or on demand from **Settings → Check for updates**. A newer release opens a popup with its notes; the APK is downloaded with progress, verified against the published checksum, and handed to the Android installer.

## Connect OpenCode

On the computer:

```bash
opencode service set password 'strong-password'
opencode service start
opencode pair
```

In AgentPort, open the **Chats** tab and switch to **OpenCode → Pair**. Scan the QR code shown by `opencode pair`, or switch to **Manual** and enter the server URL plus the service password. For a remote connection use `opencode pair --remote`, or pass a custom URL with `opencode pair --url https://your-host`.

After pairing, open the connection to browse its projects, then open a project to see only its sessions. Use **New session** to create one in that project, read the transcript, and send prompts. The session screen streams live output, groups a whole assistant reply into one turn, keeps reasoning hidden behind the psychology button, collapses tool calls into one "Used N" summary, and lets you switch the agent or model.

Minimum supported OpenCode version: **2.2.5**. The OpenCode API v2 is experimental.

## Documentation

- [Development plan](PLAN.md)
- [Release guide](docs/RELEASING.md)
- [Privacy policy](docs/PRIVACY.md)

## License

[MIT](LICENSE)
