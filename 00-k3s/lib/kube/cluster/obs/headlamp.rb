# frozen_string_literal: true

module Kube
  module Cluster
    module Obs
      class Headlamp < Kube::Cluster["HelmChart"]
        def initialize(&block)
          super {
            metadata.name = "headlamp"
            metadata.namespace = "kube-system"
            spec.chart = "headlamp"
            spec.version = "0.41.0"
            spec.repo = "https://kubernetes-sigs.github.io/headlamp"
            spec.targetNamespace = "default"
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
