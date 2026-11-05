# Privacy Policy

AgentPort is a local-first client. The project has no backend and no telemetry.

## Data stored on the device

- Chat history.
- Provider settings and model names.
- MCP server configuration.
- OpenCode connection metadata.

API keys, OAuth tokens, MCP headers, and the OpenCode token are stored in the Android Keystore via `flutter_secure_storage`. The chat database is encrypted with SQLCipher. The database key is kept in the Keystore.

## Data sent over the network

AgentPort connects directly to the endpoints you configure:

- Your model provider (for example `https://api.deepseek.com`).
- MCP servers installed from marketplaces.
- Your OpenCode server.
- `api.github.com` for update checks.
- Marketplace sources on GitHub when you open the marketplace.

Requests go to these services only. No data is routed through the AgentPort project.

## Third-party services

Data sent to a model provider, MCP server, marketplace, or OpenCode server is governed by that provider's privacy policy. Review it before connecting.

## Diagnostics

The app does not collect analytics, crash reports, or identifiers. Logs stay on the device and never include keys or tokens.

## Removing data

Uninstalling the app removes the local database and Keystore entries. Use Settings to delete individual chats, providers, and connections.

## Contact

Open an issue at <https://github.com/IWatman/AgentPort/issues>.
