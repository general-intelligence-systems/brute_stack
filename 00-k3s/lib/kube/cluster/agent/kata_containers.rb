module Kube
  module Cluster
    module Agent
      KATA_CHART_URL = "oci://ghcr.io/kata-containers/kata-deploy-charts"

      KataChart =
        Kube::Helm::Repo
          .new("kata-deploy", url: KATA_CHART_URL)
          .fetch("kata-deploy", version: '3.29.0')
    end
  end
end
