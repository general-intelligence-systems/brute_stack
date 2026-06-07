# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class VLAgent < Kube::Cluster['VLAgent']
        def initialize(name:, remote_write_url:, &block)
          super() {
            metadata.name          = name
            spec.useStrictSecurity = true
            spec.k8sCollector = {
              enabled:    true,
              msgFields:  %w[msg message log.msg],
              timeFields: %w[time ts timestamp],
            }
            spec.remoteWrite = [{ url: remote_write_url }]
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
