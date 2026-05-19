# Brute Stack

A self-contained AI agent platform that bridges the [A2A (Agent-to-Agent)](https://google.github.io/A2A/) protocol with [Matrix](https://matrix.org/) via Application Services. Run a local Matrix homeserver, a web chat client, an LLM backend, and multiple AI agents -- all with a single `docker compose up`.

Users chat through [FluffyChat](https://fluffychat.im) in the browser. Messages flow through Matrix into each agent's appservice bridge, which translates them into A2A requests. Agents process the messages (with or without an LLM) and post responses back to the Matrix room.

## Architecture

```
Browser (FluffyChat)
    |
    v
Nginx (:443, TLS)
    |
    +-- /_matrix/*        --> Synapse (:8008)
    +-- /.well-known/*    --> Synapse (:8008)
    +-- /*                --> FluffyChat (:8080)

Synapse --[appservice protocol]--> Agent's appservice.ru (:5000)
                                        |
                                        v
                                   Agent's A2A server (:4000)
                                        |
                                        v  (brute only)
                                   Ollama LLM (:11434)
                                        |
                                        v
                                   Response pushed back to Matrix room
```

Each agent runs three services in a single [Falcon](https://github.com/socketry/falcon) process:

| Port | Service | Purpose |
|------|---------|---------|
| 4000 | A2A server | Handles Agent-to-Agent protocol requests |
| 5000 | Matrix appservice | Bridges Matrix events to/from A2A |
| 8080 | Health monitor | Liveness/readiness probes (`/healthz`, `/readyz`, `/statusz`) |

## Services

| Service | Description |
|---------|-------------|
| **synapse** | Matrix homeserver (Synapse). Manages rooms, users, and routes messages to registered appservices. |
| **fluffychat** | Web-based Matrix chat client. The UI users interact with. |
| **proxy** | Nginx reverse proxy. Terminates TLS with a self-signed cert and routes traffic to Synapse and FluffyChat. |
| **ollama** | Local LLM inference server. Provides an OpenAI-compatible API for agents. |
| **brute** | LLM-powered chat agent. Receives messages via A2A, calls Ollama, and streams responses back. |
| **echo** | Test agent. Echoes back whatever you send it. Useful for verifying the pipeline works. |

## Agents

### Brute

General-purpose chat agent backed by an LLM. Uses a middleware pipeline:

```
SystemPrompt -> SteeringCheck -> LLMCall
```

Messages are processed asynchronously -- the agent returns `TASK_STATE_SUBMITTED` immediately and pushes the LLM response back via A2A push notifications. Conversation history is persisted to disk.

### Echo

Minimal test agent. Responds synchronously with `"Echo: <your message>"`. No LLM, no state. Good for verifying that the Matrix-to-A2A bridge is working.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- Ports **443** and **8008** available on the host
- A browser that can accept self-signed TLS certificates

## Quick Start

```sh
git clone https://github.com/general-intelligence-systems/brute_stack.git
cd brute_stack
docker compose up --build
```

This builds all images and starts every service. The Ollama image pre-pulls a model during build, so the first build will take a few minutes.

Once everything is running:

1. Open **https://localhost** in your browser
2. Accept the self-signed certificate warning
3. Create an account (open registration is enabled, no email required)
4. Start a direct message with **@brute:localhost** or **@echo:localhost**
5. Send a message and wait for the agent to respond

## Project Structure

```
brute_stack/
  agents/
    _common/                 # Shared agent infrastructure
      appservice.ru          #   Matrix <-> A2A bridge
      falcon.rb              #   Multi-service host config
      health_monitor.rb      #   Health check HTTP server
      registration.yaml.erb  #   K8s appservice registration template
    brute/                   # Brute agent
      config.ru              #   A2A server + LLM pipeline
      agent_card.yml         #   A2A agent card
      Gemfile
      Dockerfile
    echo/                    # Echo agent
      config.ru              #   A2A server (simple echo)
      agent_card.yml         #   A2A agent card
      Gemfile
      Dockerfile
  docker/
    synapse/                 # Matrix homeserver config
      homeserver.yaml
      appservices/           #   Static appservice registrations
        brute.yml
        echo.yml
    fluffychat/              # Web chat client config
    proxy/                   # Nginx config + TLS certs
    ollama/                  # LLM server (pre-pulls model)
  docker-compose.yml
```

## Adding a New Agent

1. Create a new directory under `agents/` (e.g. `agents/myagent/`)
2. Add a `config.ru` implementing your A2A agent logic
3. Add an `agent_card.yml` describing the agent's capabilities
4. Add a `Gemfile` with your dependencies
5. Copy and adapt a `Dockerfile` from an existing agent
6. Register the agent with Synapse:
   - Create `docker/synapse/appservices/myagent.yml` with unique tokens and a `sender_localpart`
   - Add the registration file path to `app_service_config_files` in `docker/synapse/homeserver.yaml`
7. Add the service to `docker-compose.yml`

## Environment Variables

Agents use the following environment variables (set in `docker-compose.yml`):

| Variable | Description |
|----------|-------------|
| `AGENT_NAME` | Agent identifier (matches the Matrix bot username) |
| `AS_TOKEN` | Appservice token -- agent authenticates to Synapse |
| `HS_TOKEN` | Homeserver token -- Synapse authenticates to agent |
| `HOMESERVER_ADDRESS` | Internal URL of the Synapse server |
| `HOMESERVER_DOMAIN` | Matrix server name (e.g. `localhost`) |
| `OLLAMA_API_BASE` | Ollama API endpoint (only needed for LLM agents) |

## Development

For local development without Docker, a [Nix flake](https://nixos.wiki/wiki/Flakes) is provided:

```sh
# With direnv installed, the dev shell activates automatically
cd brute_stack
# Or manually:
nix develop
```

This gives you Ruby 3.4, libyaml, OpenSSL, and kubectl.

## License

[Apache 2.0](LICENSE)
