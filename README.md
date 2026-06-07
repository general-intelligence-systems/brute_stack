# brute_stack

A local, self-contained Matrix + LLM agent stack, taught as a **progression of standalone
examples**. Each numbered folder is a complete, independently runnable stack that adds one
step of complexity over the previous one. Start at 01 and work up.

| Example | What it adds | Agent |
|---------|--------------|-------|
| [`01-basic-echo-bot/`](01-basic-echo-bot) | The wiring: a Matrix bot that echoes you back. No LLM, synchronous replies. | `@echo:localhost` |
| [`02-basic-chat-bot/`](02-basic-chat-bot) | A real Ollama LLM, async push responses, persistent sessions, steering queue. | `@chat:localhost` |
| [`03-heartbeat/`](03-heartbeat) | A periodic heartbeat (`SOUL.md`) so the agent acts proactively, not just on reply. | `@brute:localhost` |

## Run an example

Each folder is fully self-contained — its own `docker-compose.yml`, its own `docker/`
infra, and an `agent/` dir with the code plus its own copy of `_common/`.

```sh
cd 01-basic-echo-bot
docker compose up --build
```

Then open <https://localhost>, accept the self-signed cert, and sign in:

- **Username:** `@demo:localhost`
- **Password:** `demo`

A DM with the example's agent is created automatically. Full reset: `docker compose down -v`.

> **Run only one example at a time** — they all bind the same host ports (443, 8008,
> 11434, 4000/5000/8080).

## Swapping the LLM model (examples 02 and 03)

The stack ships with `qwen2.5:0.5b` pulled at build time so the first run just works — a
tiny model, fine for verifying the wiring but not much use for real conversation. For
something better, pull it into the running Ollama container and point the agent at it:

```sh
docker compose exec ollama ollama pull llama3.2
```

Then change the `model:` in that example's `agent/config.ru` to `"llama3.2:latest"` and
rebuild the agent (`docker compose up --build`).

## How it works

See [AGENTS.md](AGENTS.md) for the architecture: the per-agent Falcon process model
(A2A endpoint + Matrix appservice + supervisor), the A2A ⇄ Matrix message flow, the
steering queue, and the heartbeat.
