# 03 — Heartbeat

Builds on [02](../02-basic-chat-bot) by adding a **heartbeat**: a periodic, self-directed
tick that lets the agent act *proactively* instead of only replying when spoken to. This
is the full agent (the one the project calls `brute`).

## What this example adds over 02

- **A heartbeat service** — `agent/service.rb` now loads `agent/_common/heartbeat.rb` in
  addition to `falcon.rb`. Every `interval` seconds (default 30s) it sends a synthetic
  message to the agent's own A2A endpoint with `context_id: "heartbeat"`.
- **A soul** — `agent/SOUL.md` is interpolated into the heartbeat prompt. The agent is
  asked to review whether anything needs attention; if not, it replies with the sentinel
  `HEARTBEAT_OK` and nothing is sent to the user.
- **Proactive delivery** — when the heartbeat produces real output, it's POSTed to the
  appservice's `/_heartbeat/notify` endpoint (restored in this example's `appservice.ru`),
  which finds the user's DM room and posts the message — unprompted.
- **Heartbeat-aware handler** — `agent/config.ru` special-cases `context_id == "heartbeat"`
  (a separate `HEARTBEAT_LOCK`, skipped while a normal turn is running, responds
  synchronously) on top of the async chat path from example 02. It imports
  `SteeringCheck` from `_common/` rather than inlining it.

## Run it

```bash
docker compose up --build
```

Open <https://localhost/>, log in as `@demo:localhost` / `demo`, and DM
**@brute:localhost**.

Try:
- Chat normally — it behaves like example 02.
- Then leave it idle and watch the heartbeat tick:
  ```bash
  docker compose logs -f brute
  ```
  Every ~30s you'll see a heartbeat run — `HEARTBEAT_OK` when there's nothing to say,
  otherwise a proactive notice routed back to your DM.
- Edit `agent/SOUL.md` and rebuild to change what the agent proactively does.

Full reset: `docker compose down -v`.

> Run only one example at a time — they all bind the same host ports.
