# AgentPort Security Review — Phase 1

| Item | Value |
| --- | --- |
| Review date | 2026-11-08 |
| Scope | Android app, local data, MCP/OpenCode integration, in-app updates |
| Method | Source review of the implementation and existing tests |
| Status | Phase 1 checklist; not a third-party audit |

This document describes the security properties that are actually implemented in the
current source tree, the threats those controls address, and the gaps that remain. It is
deliberately conservative: a control is marked **Pass** only when the code path is
present and, where noted, covered by an existing test.

The review is source-based. Existing tests were inspected as evidence, but this
document does not assert a particular build or a fully green test run. The legacy
HTTP+SSE transport in `lib/data/mcp/mcp_client.dart` was reviewed for endpoint and
credential handling; protocol correctness is covered by its unit tests but was not
exercised against a third-party legacy server.

## 1. Scope and assets

### In scope

- Provider configuration and API keys.
- MCP server configuration, manual headers, and OAuth tokens.
- Chat history, messages, attachments, system prompts, and tool results.
- Backup export/import.
- OpenCode connection metadata and pairing token.
- Marketplace and plugin metadata, including trust and re-consent state.
- The in-app update channel and APK installation path.
- Android manifest/exported components and release error handling.

### Out of scope

- Security of third-party model providers, MCP servers, marketplaces, GitHub, or
  OpenCode servers.
- Marketplace content moderation and plugin code review.
- Android OS integrity, device management, and physical security.
- Server-side components (AgentPort has no backend).
- A formal cryptographic review or penetration test.

### Assets and storage

| Asset | Where it lives | Notes |
| --- | --- | --- |
| Provider API keys | Android Keystore-backed secure storage via `SecureStore` | Database stores only `apiKeyRef`; key value is written by `ProviderRepository`. |
| MCP manual header values | Android Keystore-backed secure storage via `McpCredentialStore` | Database stores header names and non-secret templates only. |
| MCP OAuth access/refresh tokens, pre-registered client ID/secret | Android Keystore-backed secure storage via `McpCredentialStore` | Token set and `McpOAuthClientConfig` are serialized as JSON into separate Keystore-backed entries. |
| Chats, messages, attachments, tool output | SQLCipher database | Encrypted at rest with a 256-bit key stored through `SecureStore` (Keystore-backed encryption). |
| Backup file | User-selected location, plaintext JSON | Excludes API keys, MCP headers/tokens, and OpenCode tokens; includes chat content and provider configuration. |
| OpenCode pairing token | Android Keystore-backed secure storage via `SecureStore` | Database stores only `tokenRef` plus server metadata; the token is sent as the HTTP Basic password. |
| Marketplace/plugin metadata | SQLCipher database | URLs, header names/templates, config hashes, trust and re-consent flags. |
| Update integrity inputs | GitHub Releases API, APK, optional SHA-256 asset | APK signature continuity is enforced by Android at install time. |

## 2. Threat model

AgentPort is a local-first Android client. The relevant trust boundaries are:

- The app process and its private storage.
- The Android Keystore and SQLCipher key.
- Remote model providers, MCP servers, marketplaces, OpenCode servers, and GitHub.
- The user's browser during the MCP OAuth flow.
- The Android package installer during updates.

### Assumptions

- The device OS and Android Keystore are not compromised.
- The user installs the app from a trusted build or a signed release.
- TLS certificate validation uses the platform default trust configuration; the app
  does not implement certificate pinning.
- A malicious MCP server or marketplace plugin is possible even when the user
  intentionally installed it.

### Threats and primary controls

| Threat | Example | Controls in place | Remaining exposure |
| --- | --- | --- | --- |
| Malicious marketplace plugin or MCP server | A plugin advertises a remote MCP server that returns prompt-injection text or destructive tools. | HTTPS-only MCP URLs; explicit plugin install; community-trust confirmation; config-hash re-consent; write-tool approval; four-round tool cap. | Tool output is untrusted model input; read-only classification is heuristic; a server can change behavior without changing its manifest. |
| Token theft at rest | Stolen device, adb backup, copied app data. | Keystore-backed secrets; SQLCipher database; `android:allowBackup="false"`; app-private support directory. | Root or a compromised OS can access the unlocked app process and decrypted data; no app-level biometric lock. |
| Token theft in transit or via redirect | A malicious MCP endpoint redirects a request, or an OAuth metadata document points at an HTTP token endpoint. | TLS by default; MCP transport requires HTTPS; OAuth uses PKCE and a loopback callback. | No certificate pinning; no app-level redirect policy; OAuth metadata/token endpoints are not required to be HTTPS; provider and OpenCode URLs accept HTTP. |
| Untrusted backup import | A crafted JSON file adds a provider pointing at an attacker-controlled URL or injects hostile chat/tool content. | Format/version validation; malformed JSON rejected; IDs regenerated; no secrets imported; import confirmation. | Imported provider URLs are not restricted; the user must still enter a key; imported chat/tool content is treated as ordinary history. |
| Secret leakage through logs, backups, or screenshots | A token appears in logcat, an exported backup, or a screenshot of the recents preview. | No intentional header/body logging; backup excludes secrets; secret fields are obscured; no analytics or crash reporting. | Backups contain plaintext chats/tool output; no `FLAG_SECURE`; bootstrap error output is not redacted; tokens exist in process memory while in use. |
| Tampered APK update | A malicious release APK or checksum is served to the app. | Stable-release filtering; GitHub TLS; SHA-256 verification when a checksum asset exists; signed CI release; Android rejects an update signed by a different key. | Checksum presence is not enforced; APK and checksum come from the same release, so SHA-256 is not independent authenticity; release signing key compromise is a single point of failure. |
| SSRF / internal-network probing via MCP | A plugin points an MCP or OAuth discovery URL at a LAN or loopback HTTPS service. | MCP URLs must be HTTPS; manifest parser rejects userinfo and secret query parameters. | No block or warning for loopback/private/link-local hosts; OAuth discovery accepts arbitrary issuer hosts. |
| Local device compromise | Rooted device, instrumentation, or malware with app-process access. | Keystore protection and database encryption raise the bar for offline data theft. | The app cannot protect secrets from a privileged attacker while it is running and unlocked. |

## 3. Implemented controls

### 3.1 Secret storage and encrypted database

- **Keystore wrapper.** `lib/core/security/secure_store.dart` wraps
  `flutter_secure_storage` with `AndroidOptions(resetOnError: true,
  storageNamespace: 'agentport')`. It generates the 256-bit SQLCipher key with
  `Random.secure()` and stores it as 64 lowercase hex characters. Every secret path
  goes through this wrapper.
- **Provider API keys.** `lib/data/repositories/provider_repository.dart` writes the
  key to the Keystore and stores only a lookup reference (`apiKeyRef`) in the
  `providers` table. Deleting a provider deletes the corresponding Keystore entry.
- **MCP header values and OAuth tokens.** `lib/data/mcp/mcp_credentials.dart` stores
  header maps and serialized `McpOAuthToken` values under per-server Keystore keys.
  `lib/data/repositories/mcp_server_repository.dart` reads them at request time and
  never persists them in Drift rows.
- **OpenCode token.** `lib/data/repositories/opencode_repository.dart` writes the
  pairing token to the Keystore under a random `tokenRef` and deletes it when the
  connection is deleted.
- **SQLCipher database.** `lib/core/db/app_database.dart` opens the database with
  `PRAGMA key = "x'<hex>'"`, `PRAGMA cipher_memory_security = ON`, and WAL mode.
  `lib/main.dart` obtains the key from `SecureStore` and opens the database in the
  app support directory. The database schema comments explicitly reserve secret
  storage for `SecureStore`.
- **Backup exclusions.** `lib/data/backup/backup_service.dart` exports providers
  without `apiKeyRef` or any key value, and does not export MCP credentials or
  OpenCode connections at all. Import validates the format/version and rejects
  malformed JSON. On import, provider IDs are regenerated and the new `apiKeyRef` has
  no value, so keys must be re-entered.

### 3.2 MCP OAuth and transport

- **Discovery and registration.** `lib/data/mcp/mcp_oauth.dart` discovers
  `/.well-known/oauth-protected-resource`, reads `authorization_servers`, then loads
  the authorization-server metadata. If a `registration_endpoint` is present, it
  performs dynamic client registration with `token_endpoint_auth_method: none`.
- **Authorization Code with PKCE.** `McpOAuthFlow.authorize` generates a random
  code verifier, builds an S256 challenge
  (`base64url(sha256(verifier))` without padding), generates a random `state`, and
  sends `response_type=code`, `code_challenge_method=S256`, and `state`.
- **Pre-registered clients.** `McpOAuthClientConfig` supplies a client ID/secret,
  optional fixed redirect URI, custom scopes, and extra authorization parameters.
  Google connections use `http://127.0.0.1:53682/callback`,
  `access_type=offline`, and `prompt=consent`. The client secret is stored in the
  Keystore, never in a Drift row.
- **Loopback callback.** `_CallbackServer.start` binds
  `InternetAddress.loopbackIPv4` on an ephemeral port or the configured fixed port and
  uses `http://127.0.0.1:<port>/callback` as the redirect URI. The callback is checked
  against the generated `state` before the code is exchanged. The HTTP scheme here is
  limited to the loopback interface and does not traverse the network.
- **Token exchange and refresh.** `exchangeCode` sends the code and verifier to the
  token endpoint with the `resource` parameter. `refresh` uses the refresh token when
  the access token is within 60 seconds of expiry. A refresh failure that surfaces as
  `McpOAuthException` deletes the stored token and requires re-authorization.
- **Bearer injection.** `McpServerRepository.requestHeaders` merges stored manual
  headers with `Authorization: Bearer <access token>`. `_connectWithAuth` retries once
  after a forced refresh on HTTP 401/403.
- **HTTPS for MCP.** `lib/data/mcp/mcp_client.dart` rejects any server URL whose scheme
  is not `https`. `lib/data/marketplace/mcp_manifest_parser.dart` rejects non-HTTPS
  MCP URLs, URLs with userinfo, and URLs with secret-looking query parameters.
- **Manual header fallback.** `lib/features/connections/mcp_server_screen.dart`
  exposes header fields for servers that use static credentials. Saving new headers
  calls `McpServerRepository.saveHeaders`, which stores them in the Keystore and
  deletes any OAuth token for that server. Sensitive header names (containing
  `authorization`, `token`, `key`, or `secret`) are obscured in the UI.
- **Auth-header handling in the SSE path.** The MCP client supplies per-session
  headers through an unmodifiable map and applies them to both the SSE GET request
  and JSON-RPC POST requests. The legacy SSE message endpoint is required to match
  the server URL's scheme, host, and port before those headers are sent.

### 3.3 Tool execution and marketplace trust

- **Read-only auto-run and write approval.** `lib/domain/entities/mcp.dart`
  (`mcpToolNeedsApproval`) treats tool names/descriptions containing write verbs
  (`create`, `delete`, `execute`, `modify`, `post`, `put`, `remove`, `run`, `send`,
  `shell`, `update`, `write`) as requiring approval. Unknown tools also require
  approval. `lib/features/chat/chat_controller.dart` prompts the user before invoking
  an approval-required tool and passes the tool name and arguments to the approval
  dialog.
- **Four-round cap.** `ChatController._generate` limits a single user turn to four
  model/tool rounds. A fifth round produces a visible error instead of an unbounded
  loop.
- **Disabled servers.** `McpServerRepository.callTool` refuses to call a disabled
  server.
- **Marketplace source validation.** `lib/data/marketplace/marketplace_sources.dart`
  accepts only HTTPS marketplace URLs and rejects userinfo and secret-looking query
  parameters. Marketplace manifests are fetched over HTTPS from the supplied source;
  plugin `.mcp.json` files are resolved to GitHub raw hosts.
- **Marketplace trust.** `lib/domain/entities/marketplace.dart` computes `TrustLevel`
  primarily from the resolved marketplace: anything outside the built-in official
  marketplace is `community`. Within the official marketplace, the manifest author
  string distinguishes `anthropic` from `verifiedPartner`; that label is advisory and
  not a cryptographic attestation.
- **Community install confirmation.** `lib/features/marketplace/plugin_detail_screen.dart`
  shows an explicit confirmation with the server URLs before installing a
  community-trust plugin.
- **Config-change re-consent.** `lib/data/repositories/marketplace_repository.dart`
  compares the installed server configuration hash with the refreshed manifest. On a
  change it sets `needsReconsent`, disables the plugin and its server rows, and blocks
  re-enabling until the user accepts the new configuration. `setPluginEnabled`
  enforces this even if the UI is bypassed.

### 3.4 OpenCode

- **Token storage.** `OpenCodeRepository` stores the pairing/manual token in the
  Keystore and keeps only a `tokenRef` in the database.
- **Authentication.** `lib/data/opencode/opencode_client.dart` sends HTTP Basic auth
  with the username `opencode` and the token as the password. The token is read from
  the Keystore per client.
- **HTTP warning.** `lib/features/opencode/opencode_pair_screen.dart` displays an
  error-colored warning when the entered server URL begins with `http://`. HTTP is
  still accepted by `openCodeBaseUri`; this is a warning, not a hard block.

### 3.5 Updates and release integrity

- **Stable channel.** `lib/data/updates/github_release_client.dart` reads the public
  GitHub Releases API and `lib/domain/entities/app_release.dart` rejects drafts,
  prereleases, and invalid versions. Only a newer stable release is returned.
- **SHA-256 verification.** `lib/data/updates/release_downloader.dart` streams the APK
  to disk and, when the release publishes `<apk>.sha256` or `SHA256SUMS`, downloads
  the checksum, parses it, compares the SHA-256 of the partial file, and deletes the
  partial file on mismatch.
- **Signed CI release.** `.github/workflows/release.yml` requires a `v*` tag whose
  commit is on `main`, verifies the tag version against `pubspec.yaml`, builds with
  release signing material injected from GitHub secrets, writes SHA-256 checksums, and
  publishes a non-draft, non-prerelease GitHub Release. `docs/RELEASING.md` documents
  the signing-key continuity requirement.
- **Install handoff.** `lib/core/updates/apk_installer.dart` and
  `android/app/src/main/kotlin/com/iwatman/agentport/ApkInstaller.kt` hand the APK to
  Android's `PackageInstaller` (or the package-installer intent as a fallback). The
  OS enforces that an update is signed with the same key as the installed app.
- **Local build caveat.** `android/app/build.gradle.kts` falls back to debug signing
  when `android/key.properties` is absent. `docs/RELEASING.md` marks such APKs as
  local-only; they cannot receive updates signed with the release key.

### 3.6 Platform hardening

- **Backups disabled.** `android/app/src/main/AndroidManifest.xml` sets
  `android:allowBackup="false"`.
- **Exported components.** `MainActivity` is exported only as the launcher entry;
  `ApkInstallResultReceiver` is `exported="false"`; the `FileProvider` is
  `exported="false"` with URI grants enabled.
- **FileProvider scope.** `android/app/src/main/res/xml/file_paths.xml` exposes
  `cache/updates` and the entire app `files/` directory. The provider is not exported
  and access requires an explicit URI grant, but the `files/` root is broader than the
  APK install flow needs.
- **Update install permission.** The manifest declares
  `android.permission.REQUEST_INSTALL_PACKAGES`. AgentPort only invokes the installer
  from the user-initiated update flow; Android's package installer still mediates the
  install.
- **Release error screen.** `lib/app/error_handling.dart` installs a neutral
  `ErrorWidget.builder` only outside debug mode, so release builds do not render
  implementation details in the widget tree.
- **No screenshots restriction.** There is no `FLAG_SECURE` in `MainActivity.kt`.
  Secret input fields are obscured in the UI instead, with the name-based limitation
  noted in section 5. The decision and residual risk are recorded there.

## 4. Verification checklist

Status values are **Pass**, **Gap**, or **Accepted risk**.

| # | Control | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Provider API keys stored in Keystore, not the database | Pass | `lib/core/security/secure_store.dart`; `lib/data/repositories/provider_repository.dart`; test `creates a provider and keeps the key out of the database` (`test/data/repositories_test.dart`). |
| 2 | MCP header values stored in Keystore, not the database | Pass | `lib/data/mcp/mcp_credentials.dart`; `lib/data/repositories/mcp_server_repository.dart`; test `stores header values in the secure store only` (`test/data/mcp_server_repository_test.dart`). |
| 3 | MCP OAuth tokens stored in Keystore | Pass | `McpCredentialStore.oauthToken`/`saveOAuthToken`; test `adds bearer tokens and refreshes expired OAuth credentials` (`test/data/mcp_server_repository_test.dart`). |
| 4 | OpenCode token stored in Keystore and deleted with the connection | Pass | `lib/data/repositories/opencode_repository.dart`; test `probe refreshes lastSeen and delete removes the token` (`test/data/opencode_repository_test.dart`). |
| 5 | Database encrypted with SQLCipher and a secure-store-held key | Pass | `lib/core/db/app_database.dart` `openEncryptedDatabase`; `lib/main.dart` bootstrap. Code inspection only; no automated test opens an encrypted file database. |
| 6 | Secret columns absent from database schema | Pass | `lib/core/db/app_database.dart` stores `apiKeyRef`, `tokenRef`, header names/templates, and non-secret metadata; tests for provider and MCP storage. |
| 7 | Backup export excludes secrets | Pass | `lib/data/backup/backup_service.dart`; test `exports chats and providers without secrets and imports them` (`test/data/backup_service_test.dart`). |
| 8 | No intentional header/body secret logging | Pass | `debugPrint` call sites are limited to `lib/main.dart` and `lib/app/error_handling.dart`; request headers and bodies are not passed to them. Bootstrap error redaction is a residual gap. |
| 9 | MCP transport requires HTTPS | Pass | `lib/data/mcp/mcp_client.dart` `connect` scheme check; `lib/data/marketplace/mcp_manifest_parser.dart` URL validation. |
| 10 | OAuth uses PKCE S256, state, and a loopback callback | Pass | `lib/data/mcp/mcp_oauth.dart` `authorize`, `_authorizationUri`, `_CallbackServer.start`; test `runs registration, browser callback, and token exchange` (`test/data/mcp_oauth_test.dart`). |
| 11 | OAuth token refresh and bearer injection | Pass | `McpServerRepository.requestHeaders`/`_connectWithAuth`; test `adds bearer tokens and refreshes expired OAuth credentials`. |
| 12 | All OAuth endpoints require HTTPS | Gap | `McpOAuthFlow.discover` accepts `http` and does not scheme-check the issuer, authorization, token, or registration endpoints (`lib/data/mcp/mcp_oauth.dart`). |
| 13 | Manual header fallback clears OAuth state | Pass | `McpServerRepository.saveHeaders` deletes the OAuth token; `lib/features/connections/mcp_server_screen.dart`; last assertion of `adds bearer tokens and refreshes expired OAuth credentials`. |
| 14 | Read-only tools auto-run; write tools require approval; four-round cap | Pass | `lib/domain/entities/mcp.dart` `mcpToolNeedsApproval`; `lib/features/chat/chat_controller.dart` `_generate`, `_executeTool`; tests `invokes a read-only MCP tool and sends the result back` and `asks for approval before running a write tool` (`test/features/chat/chat_controller_test.dart`). |
| 15 | Tool approval cannot be bypassed by a malicious tool name | Gap | Approval is inferred from server-supplied name/description text. A destructive tool named with a read verb can be auto-run; there is no per-tool policy override, and approval arguments are truncated at 2,000 characters. |
| 16 | Marketplace trust and config-change re-consent | Pass | `lib/domain/entities/marketplace.dart` `trustLevel`; `lib/data/repositories/marketplace_repository.dart` config hash/re-consent; `lib/features/marketplace/plugin_detail_screen.dart`; test `flags changes, blocks enable, and accepts the new config` (`test/data/marketplace_repository_test.dart`). |
| 17 | MCP credentials are deleted on plugin uninstall or config change | Gap | `MarketplaceRepository.uninstallPlugin` deletes database rows only; `_replaceServerRows` reuses `pluginId/serverName` IDs; no `deleteHeaders`/`deleteOAuthToken` call. Stored values remain in the Keystore and can be reused by a re-install or re-consent with the same server name. |
| 18 | OpenCode HTTP warning | Pass | `lib/features/opencode/opencode_pair_screen.dart` displays the warning for `http://` URLs. HTTP is not blocked. |
| 19 | Update channel is stable-only | Pass | `lib/data/updates/github_release_client.dart`; `lib/domain/entities/app_release.dart`; test `rejects drafts, pre-releases, and invalid tags` (`test/data/updates/app_release_test.dart`). |
| 20 | SHA-256 is verified when a checksum asset exists | Pass | `lib/data/updates/release_downloader.dart`; tests `verifies a .sha256 asset with filename and hash`, `verifies the matching line in SHA256SUMS`, and `throws a checksum failure and removes the partial file` (`test/data/updates/release_downloader_test.dart`). |
| 21 | Update install requires a verified checksum and reports verification | Gap | `DownloadedRelease.checksumVerified` is `false` when no checksum asset exists, but `UpdateController.downloadAndInstall` still installs. The UI never reads `checksumVerified` (`lib/features/updates/update_controller.dart`, `update_dialogs.dart`). |
| 22 | Release is built and signed by CI from a tag on main | Pass | `.github/workflows/release.yml`; `docs/RELEASING.md`. Actions are referenced by version tag, not commit SHA, which is a supply-chain gap. |
| 23 | Android auto backup disabled | Pass | `android/app/src/main/AndroidManifest.xml` `android:allowBackup="false"`. |
| 24 | Release error screen hides implementation details | Pass | `lib/app/error_handling.dart` installs `AgentPortErrorScreen` only when `!kDebugMode`. |
| 25 | Certificate pinning | Accepted risk | No pinning in any client; all clients use `http.Client()`/default TLS. Decision: rely on the platform default trust configuration for provider, MCP, OpenCode, marketplace, and GitHub hosts. |
| 26 | Screenshot/recents protection | Accepted risk | No `FLAG_SECURE` in `android/app/src/main/kotlin/com/iwatman/agentport/MainActivity.kt`. Decision: most secret fields are obscured (`provider_editor_screen.dart`, `mcp_server_screen.dart`, `opencode_pair_screen.dart`), but header obscuring is name-based; blocking screenshots for the whole app would prevent legitimate copying of chat content. |
| 27 | Live OAuth against a real MCP server | Gap | The Context7 OAuth flow was not completed on the emulator because Chrome crashed; only mocked OAuth tests exist (`test/data/mcp_oauth_test.dart`). Needs a real-device check. |
| 28 | Independent security review | Gap | No third-party audit or external penetration test has been performed. |
| 29 | Legacy SSE endpoint stays on the server origin and receives auth headers | Pass | `McpSession._handleEndpoint`, `_connectLegacySse`, `_postLegacy`; tests `rejects a legacy endpoint on a different host`, `completes initialize, tools/list, and tools/call over legacy SSE` (`test/data/mcp_client_test.dart`). |

## 5. Residual risks and gaps

### 5.1 Gaps that should be fixed before relying on the current controls

1. **MCP credential lifecycle.** Credentials are keyed by
   `agentport.mcp.<serverId>.*`, and server IDs are deterministic
   (`<pluginId>/<serverName>`). `uninstallPlugin` removes database rows but not the
   Keystore entries. A later reinstall with the same plugin/server name can silently
   reuse old header values or OAuth tokens. A configuration change that keeps the
   server name but changes the URL can send the old credentials to the new endpoint
   after the user accepts re-consent. This is the highest-priority gap in the current
   design because it turns a metadata update into credential reuse.
2. **Update checksum is optional and not surfaced.** SHA-256 verification runs only
   when the release publishes a checksum asset. If the asset is missing, the APK is
   installed with `checksumVerified = false`; the UI does not show that state. The APK
   and checksum also come from the same release, so the checksum detects corruption
   and transport tampering, not a compromised release account. Authenticity ultimately
   depends on Android's package-signature check and protection of the release key.
3. **OAuth discovery is not restricted to HTTPS or trusted issuers.** The MCP resource
   URL must be HTTPS, but the metadata document can advertise an HTTP or arbitrary
   authorization/token/registration endpoint. The app opens the advertised
   authorization endpoint in the browser and sends the authorization code, PKCE
   verifier, and client secret (when one was issued) to the advertised token endpoint.
   Android cleartext policy is the only backstop for HTTP. There is also no
   private-address or loopback restriction, so a malicious plugin can make the app
   probe LAN services. All HTTP clients follow the package/platform redirect behavior;
   AgentPort does not impose its own redirect allowlist or cross-origin policy for
   custom secret headers.
4. **Tool safety depends on server-controlled text.** The read-only/write decision is
   inferred from the tool name and description. A server can name a destructive tool
   `get_document` or describe it with read verbs and obtain automatic execution.
   Tool output is also untrusted model input: a malicious MCP server can return
   prompt-injection text that induces the model to call other tools or leak chat
   content. The approval dialog truncates arguments to 2,000 characters, so a long
   payload is not fully reviewable. The four-round cap limits runaway loops but does
   not establish trust.
5. **Provider keys can be sent over HTTP.** `chatCompletionsUri` accepts both `http`
   and `https` (`lib/data/api/openai_compatible_client.dart`), and there is no warning
   for an HTTP provider base URL. A user or an imported backup can configure an HTTP
   endpoint; the API key is then sent as a bearer token subject only to Android's
   cleartext policy.

### 5.2 Accepted risks

- **No certificate pinning.** Pinning provider/MCP/OpenCode hosts would break
  legitimate user-configured and self-hosted deployments. The app relies on the
  platform default TLS trust configuration. GitHub update traffic is the best
  candidate for a future pin, but it is not implemented.
- **No `FLAG_SECURE`.** Secret fields are obscured, but chat content, tool arguments,
  and the recents thumbnail can be captured. Header obscuring is name-based
  (`authorization`, `token`, `key`, `secret`), so a custom-named secret header can be
  visible in the editor and in a screenshot. This is accepted for a chat client that
  must support copying and screenshots. A narrower control for credential screens is
  recommended in Phase 2.
- **Tokens are in process memory while in use.** Dart strings cannot be reliably
  zeroized. Access tokens, refresh tokens, manual headers, and the OpenCode token
  exist in memory during requests and are visible to a debugger or a compromised
  process.
- **Rooted or compromised devices.** Keystore protection and SQLCipher raise the cost
  of offline data theft, but a privileged attacker on an unlocked device can read the
  app process, invoke Keystore operations through the app, and access decrypted chat
  data. The app has no biometric or app-level lock.
- **Plaintext backups.** Backups exclude credentials but contain chats, system
  prompts, attachments, and tool output in plaintext JSON at a user-selected
  location. A tool that returns a secret puts that secret in a chat and therefore in
  a subsequent backup.
- **HTTP OpenCode.** OpenCode accepts HTTP with a warning. Pairing tokens and chat
  traffic can be observed by a network attacker on the same segment; users who need
  confidentiality should use HTTPS or a trusted tunnel.
- **Bootstrap error output.** `lib/main.dart` prints the full bootstrap exception and
  stack trace with `debugPrint`, and the bootstrap failure screen renders
  `error.toString()`. The SQLCipher key is interpolated into a `PRAGMA key` statement;
  if a driver error ever includes that statement, the key could reach logcat or the
  screen. No redaction layer exists.
- **Broad FileProvider root.** `file_paths.xml` grants the whole app `files/` tree to
  explicit `FileProvider` URI recipients, although the update flow only needs
  `cache/updates`. The provider is non-exported, so this requires an app-controlled
  grant; it is a defense-in-depth gap rather than a direct exposure.

### 5.3 Verification gaps

- The live Context7 OAuth flow was not completed on the emulator because Chrome
  crashed. Mocked tests cover discovery, registration, callback, code exchange, and
  refresh; they do not prove interoperability with a real authorization server or the
  Android browser/loopback behavior.
- No independent third-party security audit or penetration test has been performed.
- The legacy HTTP+SSE transport is covered by unit tests for initialization, tool
  discovery, tool calls, header propagation, endpoint same-origin checks, direct JSON
  responses, and non-SSE rejection. It has not been exercised against a third-party
  legacy server.
- No automated test opens an encrypted SQLCipher file database; database encryption is
  verified by code inspection and the `sqlite3` SQLCipher hook in `pubspec.yaml`.
- No Android instrumentation test verifies `allowBackup`, exported components, or
  screenshot behavior on a real device.
- `docs/PRIVACY.md` states that logs never include keys or tokens. The reviewed code
  has no explicit redaction layer; the claim currently depends on which exception
  strings reach the global `debugPrint` handlers.

## 6. Phase 2 recommendations

Each item is intended to be small enough for a focused change with a regression test.

1. **Delete MCP credentials on uninstall and config change.** In
   `MarketplaceRepository.uninstallPlugin` and `_replaceServerRows`, call
   `McpCredentialStore.deleteHeaders` and `deleteOAuthToken` for every removed server
   ID. Add a repository test that uninstall and re-consent leave no Keystore entries.
2. **Bind MCP credentials to the server URL/config hash.** Include the URL or config
   hash in the credential key, or clear credentials when the hash changes and prompt
   the user to re-enter them. This prevents old credentials from being sent to a new
   endpoint that reuses the server name.
3. **Require a checksum for in-app updates.** Reject an APK when
   `DownloadedRelease.checksumVerified` is false, or require an explicit
   "install unverified" confirmation. Show the verification state in the update
   dialog. Add a test for the no-checksum path.
4. **Constrain update downloads to HTTPS and expected hosts.** Validate that the APK
   and checksum download URLs use `https` and belong to the expected GitHub release
   host set before downloading. Disable automatic redirects or revalidate each hop.
   Add unit tests for HTTP, off-host, and redirect targets. After the host allowlist
   exists, consider pinning only the update hosts.
5. **Enforce HTTPS for OAuth endpoints.** In `McpOAuthFlow.discover`, require
   `https` for the resource, issuer, authorization, token, and registration URLs;
   reject downgrade. Add tests for an HTTP issuer and an HTTP token endpoint.
6. **Warn on private/loopback MCP hosts.** Resolve the MCP host before connecting and
   show a warning when it is loopback, link-local, or RFC 1918. Do not hard-block,
   because local MCP servers are legitimate; make the warning part of the install or
   connect confirmation.
7. **Make tool auto-run opt-in.** Change the default so all MCP tools require approval,
   or add a per-server "allow read-only tools without approval" switch. At minimum,
   let the user override a tool's `needsApproval` flag and persist that policy. In the
   approval dialog, show the full arguments or an explicit "truncated" warning with a
   way to inspect them before allowing the call.
8. **Add `FLAG_SECURE` to credential screens only.** Apply it in the provider editor,
   MCP authorization screen, and OpenCode pairing screen rather than app-wide. Also
   obscure all header values by default with an explicit reveal action, so custom
   secret header names are not left visible. Verify that screenshots and the recents
   preview are blocked on a real device.
9. **Add a plaintext-backup warning and optional encryption.** Before export, state
   that chats and tool output are not encrypted. If encryption is in scope, use a
   password-derived key (for example Argon2id + AES-GCM) and include a format version.
10. **Redact bootstrap and release errors.** Stop printing the full exception and stack
    trace in release builds, or scrub SQLCipher key material and SQL statements before
    logging/displaying the error.
11. **Pin GitHub Actions to commit SHAs.** Replace `actions/checkout@v7`,
    `actions/setup-java@v6`, `subosito/flutter-action@v2`, and
    `softprops/action-gh-release@v2` with SHA-pinned references, and add a dependency
    update bot for review. Consider a protected environment for release secrets.
12. **Add a real-device OAuth check.** Complete the Context7 flow on a physical device,
    confirm the loopback callback and token refresh, then revoke the token and confirm
    the app returns to `needsAuth`. Record the result in this document.
13. **Commission an external review before 1.0.** Focus the review on the OAuth flow,
    MCP credential lifecycle, update path, and Android manifest/exported components.
14. **Revisit provider HTTP.** Add an explicit warning (matching OpenCode) or require
    HTTPS for provider base URLs, since the API key is sent as a bearer token. Add a
    test for an `http://` base URL.
15. **Narrow the FileProvider root.** Remove the `files-path` entry from
    `android/app/src/main/res/xml/file_paths.xml` unless a second exported file type
    needs it; keep only `cache/updates`.

## 7. Evidence index

Primary implementation files:

- `lib/core/security/secure_store.dart`
- `lib/core/db/app_database.dart`
- `lib/main.dart`
- `lib/app/error_handling.dart`
- `lib/data/backup/backup_service.dart`
- `lib/data/api/openai_compatible_client.dart`
- `lib/data/mcp/mcp_oauth.dart`
- `lib/data/mcp/mcp_credentials.dart`
- `lib/data/mcp/mcp_client.dart` (auth-header handling only)
- `lib/data/marketplace/marketplace_sources.dart`
- `lib/data/marketplace/mcp_manifest_parser.dart`
- `lib/data/opencode/opencode_client.dart`
- `lib/data/repositories/mcp_server_repository.dart`
- `lib/data/repositories/marketplace_repository.dart`
- `lib/data/repositories/provider_repository.dart`
- `lib/data/repositories/opencode_repository.dart`
- `lib/domain/entities/mcp.dart`
- `lib/domain/entities/marketplace.dart`
- `lib/domain/entities/mcp_oauth.dart`
- `lib/features/chat/chat_controller.dart`
- `lib/features/connections/mcp_server_screen.dart`
- `lib/features/marketplace/plugin_detail_screen.dart`
- `lib/features/opencode/opencode_pair_screen.dart`
- `lib/features/providers/provider_editor_screen.dart`
- `lib/features/updates/update_controller.dart`
- `lib/features/updates/update_dialogs.dart`
- `lib/data/updates/github_release_client.dart`
- `lib/data/updates/release_downloader.dart`
- `lib/domain/entities/app_release.dart`
- `lib/core/updates/apk_installer.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/iwatman/agentport/MainActivity.kt`
- `android/app/src/main/res/xml/file_paths.xml`
- `android/app/build.gradle.kts`
- `.github/workflows/release.yml`
- `docs/PRIVACY.md`
- `docs/RELEASING.md`

Security-relevant tests:

- `test/data/repositories_test.dart` — provider key stays out of the database.
- `test/data/mcp_server_repository_test.dart` — secure header storage, bearer refresh.
- `test/data/mcp_oauth_test.dart` — discovery, registration, callback, PKCE exchange, refresh.
- `test/data/backup_service_test.dart` — backup excludes secrets.
- `test/features/chat/chat_controller_test.dart` — read-only auto-run and write approval.
- `test/data/marketplace_repository_test.dart` — config-change re-consent.
- `test/data/updates/app_release_test.dart` — stable-release filtering.
- `test/data/updates/release_downloader_test.dart` — checksum parsing and mismatch handling.
- `test/features/updates/update_controller_test.dart` — download/verify/install flow.
