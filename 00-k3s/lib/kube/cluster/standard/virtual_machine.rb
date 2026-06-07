# frozen_string_literal: true

module Kube
  module Cluster
    module Standard
      class VirtualMachine < Kube::Cluster['VirtualMachine']
        def initialize(name:, &block)
          super() {
            metadata.name = name
            spec.template.metadata.labels = { 'kubevirt.io/domain' => name }
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
