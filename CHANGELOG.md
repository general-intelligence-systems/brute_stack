# Changelog

All notable changes to this project will be documented in this file.

## [v2.0.0] - 2026-06-07

### Changed
- **Restructured the repo into a progression of standalone examples.** The single monolithic stack (one `docker-compose.yml` running all three agents off a shared `agents/_common/`) is replaced by three numbered, independently runnable folders that get progressively more complex:
  - `01-basic-echo-bot/` — the echo agent: Matrix + A2A wiring only, synchronous replies, no LLM.
  - `02-basic-chat-bot/` — the chat agent: Ollama LLM, async push-notification responses, persistent `Brute::Session` history, and the per-room steering queue.
  - `03-heartbeat/` — the brute agent: adds the periodic heartbeat (`SOUL.md` + `_common/heartbeat.rb`) and `/_heartbeat/notify` relay on top of the chat behaviour.
- Each folder is fully self-contained: its own `docker-compose.yml`, its own copy of the `docker/` infra (synapse, fluffychat, proxy, bootstrap, and ollama for 02/03), and an `agent/` dir holding the agent code plus its own inlined copy of `_common/`. Only the files each example needs are included, and `_common/appservice.ru` carries the `/_heartbeat/notify` handler only in `03-heartbeat`.
- Examples run one at a time on the standard ports (443, 8008, 11434, 4000/5000/8080) — the old `4001/4002` / `5001/5002` port offsets are gone.
- Agent Dockerfiles now build from a self-contained context (`./agent`) instead of the shared `./agents` context.
- `README.md`, `AGENTS.md`, and `CLAUDE.md` rewritten for the per-folder layout; each example has its own `README.md` explaining the concept it introduces.

### Removed
- The monolithic root `docker-compose.yml`, the shared `agents/` tree, and the shared `docker/` directory.
- The agent generator (`bin/generate-agent`, `Rakefile`, `template/`, root `Gemfile`/`Gemfile.lock`), which patched the now-removed monolithic compose/homeserver files.

## [v1.1.0] - 2026-05-20

### Added
- New `chat` agent — third agent wired into the stack with its own appservice registration, Docker service, and session volume
- Agent generator (`bin/generate-agent` / `rake generate:agent[name]`) with ERB templates that scaffold a new agent, patch `docker-compose.yml` and `homeserver.yaml` automatically
- Heartbeat service (`_common/heartbeat.rb`) — periodic timer that sends a prompt to the agent's A2A endpoint and relays non-trivial responses back into Matrix via `/_heartbeat/notify`
- `SOUL.md` per agent — read on each heartbeat tick and interpolated into the prompt
- `SteeringCheck` extracted to `_common/steering_check.rb` as shared middleware
- `_common/appservice.ru` gained a `/_heartbeat/notify` endpoint for relaying heartbeat messages into Matrix rooms
- Per-agent `service.rb` files — each agent now declares which shared services it loads (falcon.rb, optionally heartbeat.rb)
- `ASYNC_SERVICE.md` documentation on the async-service architecture
- `Rakefile` and root-level `Gemfile` (rake dependency)
- README expanded with model-switching instructions and new-agent walkthrough

### Changed
- Dockerfiles now `COPY _common ./_common` (whole directory) instead of cherry-picking individual files
- Falcon launched with explicit `service.rb` (`CMD ["bundle", "exec", "falcon", "host", "service.rb"]`)
- `_common/falcon.rb` rackup path changed from `appservice.ru` to `_common/appservice.ru`
- Brute's `config.ru` refactored: heartbeat requests handled synchronously with `HEARTBEAT_LOCK`, separate from the async steering-queue flow for normal messages
- `AGENTS.md` updated for three agents, per-agent service.rb pattern, `--no-cache` tip

### Fixed
- Multiple runtime errors from the heartbeat and chat agent integration

## [v1.0.0] - 2026-05-19

### Added
- Docker Compose stack with Synapse (Matrix homeserver), FluffyChat web client, Nginx TLS proxy, Ollama, and two LLM-backed agents (brute, echo)
- `_common/` shared code: `falcon.rb` (Falcon service definitions), `appservice.ru` (Matrix appservice bot), `health_monitor.rb` (health endpoints)
- Brute agent — LLM chat agent using the `brute` and `ruby_llm` gems with Ollama, per-room steering queue for concurrent message handling, session persistence to `/app/sessions/<context_id>`
- Echo agent — simple echo-back agent for testing the appservice wiring
- Matrix appservice registrations for brute and echo (`docker/synapse/appservices/`)
- Bootstrap container that auto-creates a demo user and DM rooms with each agent
- Self-signed TLS cert and Nginx proxy config
- `AGENTS.md` and `README.md` documentation
- Setup video walkthrough

[v2.0.0]: https://github.com/general-intelligence-systems/brute_stack/compare/v1.1.0...v2.0.0
[v1.1.0]: https://github.com/general-intelligence-systems/brute_stack/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/general-intelligence-systems/brute_stack/releases/tag/v1.0.0
