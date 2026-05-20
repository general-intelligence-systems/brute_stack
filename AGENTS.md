# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A local self-contained "skynet" stack: a Matrix homeserver (Synapse) wired to LLM-backed chat agents written in Ruby. Users chat via the FluffyChat web client through an Nginx TLS proxy; messages get bridged into agents that respond using Ollama-hosted models. Everything runs under Docker Compose; `kubernetes/` and `bin/` are reserved placeholders, and the GitHub workflow is a stub.

## Bring the stack up

```bash
docker compose up --build       # builds + runs synapse, fluffychat, proxy, ollama, brute, echo
docker compose logs -f brute    # follow one service
docker compose down -v          # full reset (drops the brute-sessions and ollama-data volumes)
```

The web UI is at `https://localhost/` (self-signed cert in `docker/proxy/certs/`). Synapse listens on 8008, Ollama on 11434. Each agent exposes 3 ports: A2A server (4000/4001), Matrix appservice (5000/5001), and health endpoints (8080/8081). Brute also persists conversation sessions to the `brute-sessions` named volume at `/app/sessions/<context_id>`.

## Dev shell (Ruby work)

A Nix flake + direnv provides Ruby 3.4 and a kubeconfig-aware `kubectl`. Inside an agent directory:

```bash
direnv allow                    # first time only — `.envrc` does `use flake`
bundle install                  # gems land in $PWD/.gem (set by shellHook)
bundle exec falcon host         # run the agent stack locally (needs Synapse + Ollama reachable)
```

There is no test suite, linter, or formatter wired up — don't invent commands for them.

## Architecture

### Per-agent process model

Each agent (`agents/brute`, `agents/echo`, `agents/chat`) is a Ruby app launched by **Falcon** via a per-agent `service.rb` file. This file loads the shared `_common/falcon.rb` (which defines the three core services) and optionally loads `_common/heartbeat.rb` to add a periodic heartbeat service. Falcon's `Async::Service::Supervisor` runs the declared services in one container:

1. **`agent2agent`** (`:4000`) — Rack app from the agent's `config.ru`. Implements the A2A protocol (`A2A::Agent` + `A2A::Server`) and is what actually talks to the LLM.
2. **`matrix-appservice`** (`:5000`) — Rack app from `_common/appservice.ru`. Runs an `Async::Matrix::ApplicationService` bot that:
   - auto-joins rooms it's invited to,
   - forwards each incoming `m.room.message` to the agent's local A2A endpoint as a `SendMessage` request,
   - exposes `/_a2a/push` to receive async task-completion push notifications and relays the artifact back into the Matrix room as a notice.
3. **`supervisor`** — runs a `MemoryMonitor` (kills workers over `MEMORY_LIMIT_PER_WORKER` / `MEMORY_LIMIT_TOTAL`) and `HealthMonitor` from `_common/health_monitor.rb`, which serves `/healthz`, `/livez`, `/readyz`, `/statusz` on `:8080`. Health is "any worker registered" — it does not probe the workers themselves.

The split matters: a Matrix message arriving on `:5000` becomes an HTTP A2A call to `:4000` (same container, loopback). The A2A handler returns a `TASK_STATE_SUBMITTED` immediately and posts the final artifact later via push notification — so the appservice flow is fire-and-forget plus a callback, **not** request/response.

### Brute's LLM flow + steering queue

`agents/brute/config.ru` uses the `brute` and `ruby_llm` gems with Ollama (`llama3.2:latest` by default; `Brute.config.ollama_api_base` comes from `OLLAMA_API_BASE`). Note two non-obvious behaviors:

- **`RubyLLM.models.refresh!` runs at boot** — the container will fail to start if Ollama isn't reachable yet. The compose file's `depends_on: ollama` only waits for service start, not model availability; the `docker/ollama/Dockerfile` pulls `tinyllama` at build time as a warm-up.
- **Per-context steering queue (`STEERING_QUEUE` + `LOCK` + `RUNNING`)**: while one `context_id` (= Matrix room) has an in-flight LLM call, additional incoming messages are appended to a queue keyed by `context_id`. The custom `SteeringCheck` Rack middleware drains that queue into the LLM env's `:messages` before the next turn, so a user can "interrupt and add more" without spawning concurrent generations per room. Don't refactor this away — it's the concurrency model.

Sessions persist to `/app/sessions/<context_id>` via `Brute::Session`, so conversations survive restarts as long as the `brute-sessions` volume sticks around.

### Matrix appservice registration

Synapse loads two appservice configs at `/data/appservices/{brute,echo}.yml` (see `docker/synapse/homeserver.yaml`). Each file pins:
- `url:` to the Docker service name + appservice port (e.g. `http://brute:5000`),
- `as_token` / `hs_token` that **must match exactly** the values in `docker-compose.yml`'s env for that agent,
- a `users.regex` that grants the agent exclusive control of `@<name>:localhost`.

If you add a new agent: copy `agents/brute` as a template, create a `service.rb` that loads `_common/falcon.rb` and `_common/heartbeat.rb`, add a matching `docker/synapse/appservices/<name>.yml` (regenerate both tokens), wire it into `homeserver.yaml`'s `app_service_config_files`, and add a service to `docker-compose.yml`. `_common/registration.yaml.erb` is the template these YAMLs are derived from — currently checked in pre-rendered.

### `_common/` is copy-shared, not gem-shared

The agent Dockerfiles literally `COPY _common ./_common` into each image's `/app`. There's no shared gem and no symlink at runtime — edits to `_common/` only land in an agent's image after a rebuild of that agent. Rebuild all agents when changing `_common/`.

## Local-dev secrets

`AS_TOKEN` / `HS_TOKEN` and Synapse's `registration_shared_secret` / `macaroon_secret_key` / `form_secret` are committed in plaintext because this stack is local-only. The self-signed proxy cert in `docker/proxy/certs/` is likewise dev-only. Don't treat their presence as a leak to fix, but don't reuse them anywhere that isn't this local stack.
