module Kube
  module Cluster
    class ArgoWorkflows < Kube::Cluster["HelmChart"]
      def initialize(&block)
        super {
          metadata.name = "argo-workflows"
          metadata.namespace = "kube-system"
          spec.chart = "argo-workflows"
          spec.version = "1.0.13"
          spec.repo = "https://argoproj.github.io/argo-helm"
          spec.targetNamespace = "default"
          spec.createNamespace = true
          instance_exec(&block) if block
        }
      end
    end

    class ArgoEvents < Kube::Cluster["HelmChart"]
      def initialize(&block)
        super {
          metadata.name = "argo-events"
          metadata.namespace = "kube-system"
          spec.chart = "argo-events"
          spec.version = "2.4.21"
          spec.repo = "https://argoproj.github.io/argo-helm"
          spec.targetNamespace = "default"
          spec.createNamespace = true
          instance_exec(&block) if block
        }
      end
    end
  end
end
