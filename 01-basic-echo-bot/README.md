# 01 — Basic Echo Bot

The smallest possible agent in this stack: a Matrix bot that **echoes back** whatever
you say to it. No LLM, no async, no persistence. Start here to understand the wiring
before any intelligence is added.

## What this example teaches

- How a Ruby agent is launched by **Falcon** from `service.rb`, which loads the three
  core services in `agent/_common/falcon.rb`:
  - **`agent2agent`** (`:4000`) — the A2A protocol endpoint (`agent/config.ru`).
  - **`matrix-appservice`** (`:5000`) — the Matrix bot (`agent/_common/appservice.ru`)
    that auto-joins invited rooms and forwards each message to the A2A endpoint.
  - **`supervisor`** — memory + health monitors (`/healthz` on `:8080`).
- The **synchronous** A2A response: the handler in `agent/config.ru` immediately returns
  `TASK_STATE_COMPLETED` with an artifact of `"Echo: <your text>"`, and the appservice
  relays that straight back into the room.

Because the reply is synchronous, there is **no Ollama, no session volume, and no push
notification** — those arrive in example 02.

## Layout

```
agent/                 the agent app (its own copy of _common/)
docker/                a complete, standalone stack: synapse, fluffychat, proxy, bootstrap
docker-compose.yml     wires it all together
```

## Run it

```bash
docker compose up --build
```

Then open <https://localhost/> (self-signed cert — accept the warning), log in as
`@demo:localhost` / `demo`, and open the DM with **@echo:localhost** that the bootstrap
container created. Every message comes back as `Echo: <text>`.

Health check: `curl -k http://localhost:8080/healthz` → `200`.

Full reset: `docker compose down -v`.

> Run only one example at a time — they all bind the same host ports (443, 8008, 4000…).
