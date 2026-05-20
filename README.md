# brute_stack

## Start

```sh
docker compose up -d
```

## Log in

Open <https://localhost>, accept the self-signed cert, and sign in:

- **Username:** `@demo:localhost`
- **Password:** `demo`

Two chats are waiting: one with `@brute:localhost`, one with `@echo:localhost`.

<video src="assets/setup-video.mp4" width="320" height="240" controls></video>

## LLM Model

The stack ships with `qwen2.5:0.5b` pulled at build time so the first `docker compose up` just works. This is a tiny model (0.5B params) — fine for verifying the wiring but not much use for real conversation.

You probably want something like `llama3.2:latest`. Pull it into the running Ollama container:

```sh
docker compose exec ollama ollama pull llama3.2
```

Then update the model name in `agents/brute/config.ru`:

```ruby
llm = Brute::Agent.new(
  provider: :ollama,
  model:    "llama3.2:latest",   # <-- change this
  ...
)
```

Rebuild brute (`docker compose up --build brute`) and you're set.

## Adding a New Agent

```sh
bin/generate-agent <name>
```

Or manually:

1. `cp -r ./agents/brute ./agents/<name>` - update `Dockerfile`, `config.ru`, `agent_card.yml`
2. Generate tokens: `openssl rand -hex 32` (one for AS_TOKEN, one for HS_TOKEN)
3. `docker/synapse/appservices/<name>.yml` - copy `brute.yml`, substitute name + tokens
4. `docker/synapse/homeserver.yaml` - add `- /data/appservices/<name>.yml` to `app_service_config_files`
5. `docker-compose.yml` - add service block, add to bootstrap `depends_on` + `DEMO_AGENTS`

Then edit `agents/<name>/config.ru` with your logic and:

```sh
docker compose up --build
```
