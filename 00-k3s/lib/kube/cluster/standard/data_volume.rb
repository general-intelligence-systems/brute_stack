# frozen_string_literal: true

module Kube
  module Cluster
    module Standard
      class DataVolume < Kube::Cluster['DataVolume']
        def initialize(name:, &block)
          super() {
            metadata.name = name
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
