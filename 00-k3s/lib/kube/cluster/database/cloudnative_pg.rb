# frozen_string_literal: true

module Kube
  module Cluster
    module Database
      class CloudNativePg < Kube::Cluster["HelmChart"]
        def initialize(&block)
          super {
            metadata.name = "cloudnative-pg"
            metadata.namespace = "kube-system"
            spec.chart = "cloudnative-pg"
            spec.version = "1.0.13"
            spec.repo = "https://general-intelligence-systems.github.io/bitnami-charts"
            spec.targetNamespace = "cloudnative-pg"
            spec.createNamespace = true

            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
