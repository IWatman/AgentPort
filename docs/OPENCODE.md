# OpenCode in AgentPort

This document maps the OpenCode API surface to what AgentPort supports today. The
source of truth is the OpenCode v2 server (`/openapi.json`); the app targets
OpenCode **2.2.5+**.

## Implemented

### Projects

- List projects known to the server.
- Create a project by browsing directories on the OpenCode host through
  `GET /api/fs/list` and registering the selection through
  `GET /api/location?location[directory]=...`.
- Open a project and list only its sessions.
- Switch drives discovered from existing project paths; go up one level.
- Hidden directories are not shown in the browser.

### Sessions

- Create a session in a project.
- Read a session transcript with images and file attachments.
- Rename and delete sessions; show the session ID and metadata.
- Send prompts, run slash commands, mention project files, and attach images or
  text files.
- Stream replies with SSE, stop generation, auto-reconnect with backoff, and
  refresh when another client changes the session.
- Switch the session agent, model, and model variant.
- Group a whole assistant reply into one turn; reasoning is hidden behind a
  psychology button, tools collapse into one summary, and only the final answer
  is shown.
- Jump to the true bottom of a lazily built transcript in one tap.

### Session context

The **info** button in a session opens the context sheet:

- Session ID, project directory, provider, model, and agent.
- Context limit (from `GET /api/model`) and total token usage.
- Token breakdown: input, output, reasoning, cache read, cache write, total.
- Cost, creation time, and last activity.
- Message counts: all, user, assistant, and current context window.
- The latest system prompt found in the loaded transcript pages.

### Extensions

The **grid** button in a session opens the extensions sheet:

- MCP servers configured on the host with status (`connected`, `failed`,
  `needs-auth`, `pending`, `disabled`) and server error text.
- Plugins loaded by the host: external plugins are listed; built-in plugins are
  counted.
- Skills exposed at the project directory with count, search, and descriptions.
- LSP is configured on the host, but the OpenCode API does not expose language
  server status. AgentPort says so explicitly instead of inventing a list.

## Available in the API, not implemented in the app yet

These are real OpenCode v2 capabilities and are candidates for the next phase:

### Sessions and context

- Fork, move, compact, import, and export sessions.
- Stage, clear, and commit a session revert.
- Session diff (`GET /api/session/{id}/diff`).
- Pending permissions and forms, replies, and saved permission rules.
- Session statistics for a date range (`/api/experimental/session/stats`).
- Instruction entries and session log.

### Workspace

- Interactive PTY and persistent terminal sessions (WebSocket transport).
- Shell commands and their streamed output.
- Filesystem browser, read, write, and watch. AgentPort currently uses the
  filesystem only for `@` file mentions and the project folder picker.
- VCS info, status, branches, diff, and repository initialization.
- Worktrees: list, create, remove, and refresh.
- Project references and artifacts.
- Background jobs and schedules.

### Extensions and configuration

- Connect, disconnect, add, and remove OpenCode MCP servers.
- MCP resources and OAuth/integration sign-in.
- Plugin update checks and updates.
- Skill activation inside a session.
- Read and write OpenCode configuration.
- Provider and model inventory, voice models, image generation, web search.

### Deliberately not exposed

- `GET /api/config` can contain provider keys, MCP environment variables, and
  other secrets. AgentPort does not render or edit the raw OpenCode config.
- Secrets from OpenCode stay on the host; AgentPort only shows non-secret
  status, counts, names, and errors.
- PTY and terminal sessions are interactive WebSocket surfaces. They need a
  dedicated mobile terminal UI and are not part of this iteration.

## Compatibility

- Minimum OpenCode version: **2.2.5**.
- The OpenCode v2 API is experimental; endpoints and response shapes can change.
- AgentPort tolerates unknown fields and ignores unsupported message types
  instead of failing the transcript.
