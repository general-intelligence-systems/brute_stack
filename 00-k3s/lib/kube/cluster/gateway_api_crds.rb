module Kube
  module Cluster
    GATEWAY_API_VERSION = "v1.5.0"
    GATEWAY_API_URL = "https://github.com/kubernetes-sigs/gateway-api/releases/download/#{GATEWAY_API_VERSION}/standard-install.yaml"

    GatewayApiCrds =
      Kube::Schema::Manifest.parse(
        URI.open(GATEWAY_API_URL).read
      )
  end
end
