# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class VLSingle < Kube::Cluster['VLSingle']
        def initialize(name:, retention_period: '30d', &block)
          super() {
            metadata.name        = name
            spec.retentionPeriod = retention_period
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
