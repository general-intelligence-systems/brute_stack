# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class VMNodeScrape < Kube::Cluster['VMNodeScrape']
        def initialize(name:, job:, path: nil, interval: '30s', &block)
          super() {
            metadata.name        = name
            spec.scheme          = 'https'
            spec.tlsConfig       = { insecureSkipVerify: true }
            spec.bearerTokenFile = '/var/run/secrets/kubernetes.io/serviceaccount/token'
            spec.honorLabels     = true
            spec.interval        = interval
            spec.path            = path if path
            spec.relabelConfigs  = [{ targetLabel: 'job', replacement: job }]
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
