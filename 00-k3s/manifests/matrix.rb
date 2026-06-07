# frozen_string_literal: true
#
# Matrix homeserver (Synapse + Matrix Authentication Service) via the element-hq
# ESS Helm chart, installed by k3s's built-in helm-controller (HelmChart CRD in
# kube-system). Adapted from the production ns/ai manifest for a local single-node k3s:
#
#   - chart-native Postgres (postgres.enabled = true) instead of external cloudnative-pg
#   - MAS with local password auth (the production OIDC upstreams aren't reachable here)
#   - localhost ingress hosts, no nodeSelector, no whatsapp bridge, no appservices
#
# FluffyChat and Ollama live in their own manifest files.

MatrixManifest = Manifest.new(
  Kube::Cluster['HelmChart'].new do
    metadata.name        = 'matrix-stack'
    metadata.namespace   = 'kube-system'
    spec.chart           = 'oci://ghcr.io/element-hq/ess-helm/matrix-stack'
    spec.version         = '26.3.0'
    spec.targetNamespace = 'ai'
    spec.createNamespace = false
    spec.valuesContent   = Hash.vivify do
      self.serverName      = 'localhost'
      ingress.className    = 'traefik'
      synapse.ingress.host = 'localhost'

      synapse.media.storage.storageClassName = 'local-path'

      # Chart-native Postgres for both Synapse and MAS (replaces external cloudnative-pg).
      postgres.enabled = true

      # We ship FluffyChat as the web client instead of Element Web.
      elementWeb.enabled   = false
      elementAdmin.enabled = false
      matrixRTC.enabled    = false

      matrixAuthenticationService.ingress.host = 'auth.localhost'
      # Local password auth — the production OIDC upstreams (Authelia, kremlin) aren't
      # reachable from a local cluster, so allow a plain account to sign in.
      matrixAuthenticationService.additional[:'0-passwords'] = { config: <<~YAML
        passwords:
          enabled: true
      YAML
      }

      wellKnownDelegation.enabled = true
    end.to_yaml
  end
)
