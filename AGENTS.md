# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A teaching repo for building a local, self-contained "skynet" stack: a Matrix homeserver (Synapse) wired to LLM-backed chat agents written in Ruby. Users chat via the FluffyChat web client through an Nginx TLS proxy; messages get bridged into agents that respond — either with canned text or via Ollama-hosted models.

Instead of one monolithic stack, the repo is a **progression of standalone examples**, each in a numbered folder that gets one step more complex:

- **`01-basic-echo-bot/`** — the wiring only: a Matrix bot that echoes your messages back. No LLM, synchronous responses.
- **`02-basic-chat-bot/`** — adds a real Ollama LLM, async push-notification responses, persistent `Brute::Session` history, and a per-room steering queue.
- **`03-heartbeat/`** — adds a periodic heartbeat (`SOUL.md` + `_common/heartbeat.rb`) so the agent can act proactively, not just reply.

Each folder is **fully self-contained and independently runnable** — its own `docker-compose.yml`, its own copy of the `docker/` infra (synapse, fluffychat, proxy, bootstrap, and ollama where needed), and an `agent/` dir holding the agent code plus its own copy of `_common/`. You can read one folder top to bottom, and the progression is visible by diffing folder N against N+1. `kubernetes/` and `bin/` are reserved placeholders, and the GitHub workflow is a stub.

## Bring an example up

Work inside one example folder. **Run only one at a time** — they all bind the same host ports (443, 8008, 11434, 4000/5000/8080).

```bash
cd 03-heartbeat
docker compose up --build       # builds + runs synapse, fluffychat, proxy, (ollama,) the agent, bootstrap
docker compose logs -f brute    # follow the agent (service name = brute/chat/echo per folder)
docker compose down -v          # full reset (drops that example's session + ollama volumes)
```

If changes aren't persisting to the images then sometimes you need to run `docker compose build --no-cache`.

The web UI is at `https://localhost/` (self-signed cert in each example's `docker/proxy/certs/`). Synapse listens on 8008, Ollama on 11434. The agent exposes 3 ports: A2A server (4000), Matrix appservice (5000), and health endpoints (8080). The chat and heartbeat examples persist conversation sessions to a named volume at `/app/sessions/<context_id>`.

## Dev shell (Ruby work)

A Nix flake + direnv at the repo root provides Ruby 3.4 and a kubeconfig-aware `kubectl`:

```bash
direnv allow                    # first time only — `.envrc` does `use flake`
```

Inside an example's `agent/` dir you can `bundle install` and `bundle exec falcon host service.rb` to run it locally (needs Synapse + Ollama reachable). There is no test suite, linter, or formatter wired up — don't invent commands for them.

## Architecture

### Per-agent process model

Each example's `agent/` is a Ruby app launched by **Falcon** via a `service.rb` file. This file loads the agent's own copy of `_common/falcon.rb` (which defines the three core services) and, in `03-heartbeat`, also loads `_common/heartbeat.rb` to add a periodic heartbeat service. Falcon's `Async::Service::Supervisor` runs the declared services in one container:

1. **`agent2agent`** (`:4000`) — Rack app from the agent's `config.ru`. Implements the A2A protocol (`A2A::Agent` + `A2A::Server`) and is what actually talks to the LLM (in 02/03).
2. **`matrix-appservice`** (`:5000`) — Rack app from `_common/appservice.ru`. Runs an `Async::Matrix::ApplicationService` bot that:
   - auto-joins rooms it's invited to,
   - forwards each incoming `m.room.message` to the agent's local A2A endpoint as a `SendMessage` request,
   - exposes `/_a2a/push` to receive async task-completion push notifications and relays the artifact back into the Matrix room as a notice,
   - in `03-heartbeat` only, also exposes `/_heartbeat/notify` to relay proactive heartbeat output into the user's DM room.
3. **`supervisor`** — runs a `MemoryMonitor` (kills workers over `MEMORY_LIMIT_PER_WORKER` / `MEMORY_LIMIT_TOTAL`) and `HealthMonitor` from `_common/health_monitor.rb`, which serves `/healthz`, `/livez`, `/readyz`, `/statusz` on `:8080`. Health is "any worker registered" — it does not probe the workers themselves.

The split matters: a Matrix message arriving on `:5000` becomes an HTTP A2A call to `:4000` (same container, loopback).

### The progression (echo → chat → heartbeat)

- **01 echo** (`agent/config.ru`) responds **synchronously**: the handler returns `TASK_STATE_COMPLETED` with an `"Echo: <text>"` artifact, which the appservice relays inline. No Ollama, no sessions, no steering, no push. Its `_common/appservice.ru` has the `/_heartbeat/notify` handler stripped out.
- **02 chat** (`agent/config.ru`) uses the `brute` and `ruby_llm` gems with Ollama (`qwen2.5:0.5b`; `Brute.config.ollama_api_base` comes from `OLLAMA_API_BASE`). The A2A handler returns `TASK_STATE_SUBMITTED` immediately and runs the LLM in a background `Async` task that POSTs the result to the appservice's `/_a2a/push` — so the appservice flow is fire-and-forget **plus a callback**, not request/response. Sessions persist to `/app/sessions/<context_id>` via `Brute::Session`. `SteeringCheck` is **inlined** at the top of this `config.ru`.
- **03 heartbeat** (`agent/config.ru`) is 02 plus a `context_id == "heartbeat"` branch (its own `HEARTBEAT_LOCK`, responds synchronously, skipped while a normal turn is running). `service.rb` additionally loads `_common/heartbeat.rb`, which every `interval` seconds renders `SOUL.md` into a prompt, sends it to the agent, and — unless the reply is the sentinel `HEARTBEAT_OK` — POSTs it to `/_heartbeat/notify`. Here `SteeringCheck` is **imported** from `_common/steering_check.rb`.

**Per-context steering queue (`STEERING_QUEUE` + `LOCK` + `RUNNING`)**: while one `context_id` (= Matrix room) has an in-flight LLM call, additional incoming messages are appended to a queue keyed by `context_id`. The `SteeringCheck` Rack middleware drains that queue into the LLM env's `:messages` before the next turn, so a user can "interrupt and add more" without spawning concurrent generations per room. Don't refactor this away — it's the concurrency model for 02 and 03.

The `docker/ollama/Dockerfile` pulls a model at build time as a warm-up; `RubyLLM.models.refresh!` runs at boot, so the agent container needs Ollama reachable to start.

### Matrix appservice registration

Each example's Synapse loads exactly one appservice config at `/data/appservices/<name>.yml` (see that folder's `docker/synapse/homeserver.yaml`). The file pins:
- `url:` to the Docker service name + appservice port (e.g. `http://brute:5000`),
- `as_token` / `hs_token` that **must match exactly** the values in that folder's `docker-compose.yml` env for the agent,
- a `users.regex` that grants the agent exclusive control of `@<name>:localhost`.

The agents keep their original identities across the examples — `echo`, `chat`, `brute` — so the folder name describes the *lesson* while the agent inside keeps its working tokens and registration.

### `_common/` is inlined per example

Each example carries its **own copy** of just the `_common` files it needs (`falcon.rb`, `appservice.ru`, `health_monitor.rb`, plus `heartbeat.rb` + `steering_check.rb` in 03). There is no cross-example sharing — editing `01-basic-echo-bot/agent/_common/appservice.ru` affects only example 01. This duplication is deliberate: it keeps each folder readable and runnable on its own.

## Local-dev secrets

`AS_TOKEN` / `HS_TOKEN` and Synapse's `registration_shared_secret` / `macaroon_secret_key` / `form_secret` are committed in plaintext because this stack is local-only. The self-signed proxy cert in each `docker/proxy/certs/` is likewise dev-only. Don't treat their presence as a leak to fix, but don't reuse them anywhere that isn't this local stack.
