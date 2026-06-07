# 00-k3s — Matrix + Ollama + FluffyChat on a local k3s

This base runs a single-node **k3s** inside docker-compose and applies the project's
Kubernetes manifests to it. The manifests are the same Ruby `kube_cluster` DSL files used for
the production `kremlin` cluster (`~/infra/kremlin/ns/ai`), copied here and adapted for a bare
local k3s.

```
manifests.rb            ties the three manifests together + the middleware stack
manifests/
  matrix.rb             Synapse + MAS via the element-hq ESS Helm chart
  ollama.rb             Ollama (pulls qwen2.5:0.5b)
  fluffychat.rb         FluffyChat web client
lib/                    vendored kube/cluster DSL resources (Standard::*, Middleware::*, …)
common.rb  Gemfile      the render harness + gem deps (kube_cluster, kube_schema, scampi, …)
applier/                container that renders the manifests to YAML and kubectl-applies them
docker-compose.yml      k3s server + the one-shot applier
```

## What differs from the production manifests

The production `ns/ai` manifests lean on cluster services a bare k3s doesn't have. The local
adaptations (see `manifests/matrix.rb`):

- **Chart-native Postgres** (`postgres.enabled = true`) instead of external cloudnative-pg +
  external-secrets.
- **MAS with local password auth** — the production OIDC upstreams (Authelia, the kremlin app)
  aren't reachable locally, so a plain account can sign in.
- **localhost ingress hosts**, no `nodeSelector`, no mautrix-whatsapp bridge, no appservices.
- **Ollama**: the agentgateway proxy/route resources are dropped (no CRDs in bare k3s); pulls the
  lightweight `qwen2.5:0.5b`.

k3s supplies the rest out of the box: Traefik (ingress), local-path-provisioner (`local-path`
PVCs), ServiceLB, and the HelmChart CRD/helm-controller that installs the ESS chart.

## Run it

```bash
docker compose up --build
```

The `k3s` service starts the cluster; the `applier` waits for the API, ensures the `ai`
namespace, renders `manifests.rb` to YAML, and `kubectl apply`s it, then exits 0.

Inspect the cluster (kubectl runs inside the k3s container):

```bash
docker compose exec k3s kubectl get pods -n ai
docker compose exec k3s kubectl get svc,ingress -n ai
docker compose exec k3s kubectl get helmchart -n kube-system
docker compose exec k3s kubectl -n ai logs deploy/ollama -c pull-models   # model pull
```

First boot is slow: helm-controller pulls the ESS chart and the Synapse/MAS/Postgres images, and
Ollama pulls its model. Watch `get pods -n ai` until everything is `Running`.

Web UI: FluffyChat and Synapse are exposed through Traefik on the host's ports 80/443.

Re-apply after editing a manifest (rebuild bakes the change into the applier image):

```bash
docker compose up --build applier
```

Full teardown (drops the cluster + volumes):

```bash
docker compose down -v
```

> Uses host ports 6443/80/443 — don't run it alongside another example that binds 80/443.
