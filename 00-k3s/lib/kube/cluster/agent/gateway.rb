module Kube
  module Cluster
    module Agent
      class GatewayCrds < Kube::Cluster["HelmChart"]
        def initialize(&block)
          super {
            metadata.name = "agentgateway-crds"
            metadata.namespace = "kube-system"
            spec.chart = "oci://cr.agentgateway.dev/charts/agentgateway-crds"
            spec.version = "v1.1.0"
            spec.targetNamespace = "agentgateway-system"
            spec.createNamespace = true
            instance_exec(&block) if block
          }
        end
      end

      class Gateway < Kube::Cluster["HelmChart"]
        def initialize(&block)
          super {
            metadata.name = "agentgateway"
            metadata.namespace = "kube-system"
            spec.chart = "oci://cr.agentgateway.dev/charts/agentgateway"
            spec.version = "v1.1.0"
            spec.targetNamespace = "agentgateway-system"
            spec.createNamespace = true
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
