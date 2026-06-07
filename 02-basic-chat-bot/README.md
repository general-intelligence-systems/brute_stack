# 02 — Basic Chat Bot

Builds on [01](../01-basic-echo-bot) by replacing the canned echo with a **real LLM
reply** from a local Ollama model. This is where the agent stops being synchronous and
gains the three behaviours that make a real chat agent work: async responses, session
persistence, and a steering queue.

## What this example adds over 01

- **Ollama-backed generation** — `agent/config.ru` uses the `brute` gem, points
  `Brute.config.ollama_api_base` at the new `ollama` service, and generates replies with
  `qwen2.5:0.5b`. The compose file gains an `ollama` service + `OLLAMA_API_BASE` env.
- **Async push responses** — the A2A handler returns `TASK_STATE_SUBMITTED` *immediately*
  and runs the LLM call in a background `Async` task. When it finishes it POSTs the
  artifact to the appservice's `/_a2a/push` endpoint, which relays it into the room. So
  the flow is now fire-and-forget **plus a callback**, not request/response.
- **Persistent sessions** — each conversation is a `Brute::Session` saved under
  `/app/sessions/<room_id>` on the `chat-sessions` volume, so history survives restarts.
- **Steering queue** — the inline `SteeringCheck` middleware (top of `agent/config.ru`)
  lets you fire several messages while one generation is in flight; they're drained into
  the next turn instead of spawning concurrent generations per room.

Still **no heartbeat** — that's example 03.

## Run it

```bash
docker compose up --build
```

First boot pulls the model layer, so give Ollama a minute. Open <https://localhost/>, log
in as `@demo:localhost` / `demo`, and DM **@chat:localhost**.

Try:
- Send a question → a generated reply arrives a few seconds later (the push path).
- Fire two messages quickly → they batch into a single reply (the steering queue).
- `docker compose down && docker compose up` → prior history is still there
  (the `chat-sessions` volume).

Full reset (drops sessions + model cache): `docker compose down -v`.

> Run only one example at a time — they all bind the same host ports.
