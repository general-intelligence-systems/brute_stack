module Kube
  module Cluster
    FLUXCD_URL = "https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest/download/install.yaml"

    FluxCD =
      Kube::Schema::Manifest.parse(
        URI.cache(FLUXCD_URL).read
      )
  end
end
