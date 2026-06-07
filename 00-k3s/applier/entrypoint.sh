#!/usr/bin/env bash
# Wait for the k3s API, render the Ruby manifests to YAML, and apply them.
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/output/kubeconfig.yaml}"

echo "==> waiting for k3s kubeconfig at $KUBECONFIG"
until [ -s "$KUBECONFIG" ]; do sleep 1; done

# k3s writes `server: https://127.0.0.1:6443` — rewrite to the compose service name so
# this container can reach the API. (--tls-san k3s makes the server cert valid for it.)
sed -i 's#https://127.0.0.1:6443#https://k3s:6443#g' "$KUBECONFIG"

echo "==> waiting for k3s API to be ready"
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done

echo "==> ensuring namespace 'ai'"
kubectl get namespace ai >/dev/null 2>&1 || kubectl create namespace ai

echo "==> rendering manifests"
cd /work
bundle exec ruby -r ./common.rb manifests.rb > /tmp/rendered.yaml
echo "    rendered $(grep -c '^kind:' /tmp/rendered.yaml || echo '?') resources"

echo "==> applying manifests"
kubectl apply -f /tmp/rendered.yaml

echo "==> done"
