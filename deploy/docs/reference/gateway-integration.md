---
title: "Gateway Integration Guide"
summary: "Developer guide for building custom interfaces and pairing desktop applications with the OpenClaw Gateway."
---

# Gateway Integration Guide

This guide provides technical specifications for third-party developers building custom user interfaces (e.g., Flutter Desktop, Mobile) that interact with the OpenClaw Gateway.

## Communication Protocol

The OpenClaw Gateway uses a JSON-over-WebSocket protocol (JSON-RPC variant) for real-time interaction and a REST API for stateful resources.

### WebSocket Connection

- **Endpoint**: `ws://<host>:<port>/ws` (Default: `ws://127.0.0.1:18789/ws`)
- **Protocol**: Custom JSON framing.

#### Connection Handshake
Upon connecting, the client should send a `hello` request to identify itself and negotiate capabilities.

```json
{
  "type": "req",
  "id": "1",
  "method": "hello",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "custom-flutter-ui",
      "version": "1.0.0",
      "platform": "windows",
      "mode": "harness"
    },
    "role": "operator",
    "scopes": ["operator.admin", "operator.read", "operator.write"],
    "auth": { "token": "YOUR_GATEWAY_TOKEN" }
  }
}
```

#### Request/Response Format
All requests must include a unique `id` for correlation.

- **Request**: `{ "type": "req", "id": "uuid", "method": "...", "params": { ... } }`
- **Response**: `{ "type": "res", "id": "uuid", "ok": true, "payload": { ... } }`
- **Error**: `{ "type": "res", "id": "uuid", "ok": false, "error": { "code": "...", "message": "..." } }`

#### Events (Server-to-Client)
The server pushes updates (e.g., chat deltas, log lines) as events.

- **Format**: `{ "type": "event", "event": "...", "payload": { ... } }`
- **Common Events**: `chat.event`, `presence.update`, `logs.tail`.

---

## Exhaustive RPC Catalog

### System & Infrastructure
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `hello` | Negotiates protocol and authenticates. | `client`, `auth`, `scopes` |
| `node.list` | Lists all connected gateway nodes/instances. | - |
| `logs.tail` | Streams real-time gateway logs. | `cursor`, `limit` |
| `update.run` | Initiates a gateway software update. | `sessionKey` |

### Configuration
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `config.get` | Returns the current global configuration. | - |
| `config.schema` | Returns the JSON schema for config validation. | - |
| `config.set` | Saves config to disk (requires restart). | `raw` (YAML/JSON) |
| `config.apply` | Applies config changes immediately. | `raw`, `sessionKey` |
| `config.openFile` | Opens `openclaw.json` in the system editor. | - |

### Agents
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `agents.list` | Lists available agents and the default ID. | - |
| `tools.catalog` | Lists tools/skills available to an agent. | `agentId` |
| `agents.files.list`| Lists files in an agent's knowledge base. | `agentId` |
| `agents.files.get` | Gets content of an agent knowledge file. | `agentId`, `name` |
| `agents.files.set` | Saves/Updates an agent knowledge file. | `agentId`, `name`, `content` |
| `agent.identity.get`| Gets name, avatar, and metadata for an agent. | `agentId` |
| `skills.status` | Returns a report of all installed skills. | - |
| `skills.update` | Enables/disables skills or sets API keys. | `skillKey`, `enabled`, `apiKey` |
| `skills.install` | Installs a new skill from a string/url. | `name`, `installId` |

### Chat & Sessions
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `chat.send` | Sends a message to an agent. | `sessionKey`, `message`, `attachments` |
| `chat.history` | Retrieves message history for a session. | `sessionKey`, `limit` |
| `chat.abort` | Cancels a running agent response. | `sessionKey`, `runId` |
| `sessions.list` | Lists all chat sessions with metadata. | `limit`, `activeMinutes` |
| `sessions.subscribe`| Subscribes to real-time session updates. | - |
| `sessions.patch` | Renames or configures session model/thinking.| `key`, `label`, `thinkingLevel` |
| `sessions.delete` | Deletes a session and its transcript. | `key`, `deleteTranscript` |

### Channels & Communication
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `channels.status` | Returns connectivity status for all channels. | `probe` (bool) |
| `channels.logout` | Logs out from a specific channel (e.g. Zalo). | `channel` |
| `web.login.start` | Initializes WhatsApp/Web QR login flow. | `force` |
| `web.login.wait` | Waits/Polls for QR scan completion. | - |

### Usage & Analytics
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `sessions.usage` | Aggregate token/cost usage per session. | `startDate`, `endDate` |
| `usage.cost` | Summary of total costs across all models. | `startDate`, `endDate` |
| `sessions.usage.logs`| Detailed audit trail/logs for a session. | `key`, `limit` |

### Automation (Cron)
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `cron.status` | Returns current scheduler status/next wake. | - |
| `cron.list` | Lists all scheduled jobs. | `query`, `offset`, `limit` |
| `cron.add` | Creates a new scheduled job. | `name`, `schedule`, `payload` |
| `cron.update` | Modifies an existing job. | `id`, `patch` |
| `cron.run` | Manually triggers a job immediately. | `id`, `mode` |
| `cron.remove` | Deletes a scheduled job. | `id` |

### Device Pairing & Tokens
| Method | Description | Key Params |
| :--- | :--- | :--- |
| `device.pair.list` | Lists pending and paired devices. | - |
| `device.pair.approve`| Approves a pending device request. | `requestId` |
| `device.pair.reject` | Rejects a pending device request. | `requestId` |
| `device.token.rotate`| Rotates the auth token for a device. | `deviceId`, `role` |
| `device.token.revoke`| Revokes the auth token for a device. | `deviceId`, `role` |

---

## Web UI Screen Mapping

To replicate the OpenClaw experience in your Desktop UI, consider these functional blocks:

1. **Dashboard (Overview)**:
   - Use `cron.status`, `channels.status`, and `usage.cost` for high-level health metrics.
   - Display "Attention Items" and "Event Logs" from the `hello` snapshot or `logs.tail`.

2. **Chat Interface**:
   - Primary view using `chat.send` and `chat.history`.
   - Support for "Thinking Levels" (system prompt biasing) via `sessions.patch`.
   - Real-time rendering of `chat.event` (deltas) and tool call streams.

3. **Agent Library**:
   - Manage agent personas via `agents.list` and `agent.identity.get`.
   - Edit knowledge files using `agents.files.*`.
   - Toggle skills/tools via `skills.update`.

4. **Session Manager**:
   - Navigation sidebar using `sessions.list`.
   - Search and batch-delete functionality using `sessions.delete`.

5. **Channel Settings**:
   - Dedicated configuration page for Telegram, Discord, Signal, etc.
   - Interactive QR login flow for WhatsApp using `web.login.start`.

6. **Infrastructure & Devices**:
   - Manage paired devices (e.g. mobile apps) via `device.pair.*`.
   - View connected gateway nodes via `node.list`.

---

## Authentication Modes

1. **Device Pairing (Recommended for UI)**:
   - Generate a local device identity (ECDSA keypair).
   - Sign a handshake payload and send to `device.pair.request`.
   - Once approved in the existing Control UI, use the returned `deviceToken` for all future `hello` requests.

2. **Direct Token**:
   - Provide the gateway's `CONTROL_TOKEN` directly in the `hello` request's `auth` field.
   - Suitable for local development or single-tenant installs.
