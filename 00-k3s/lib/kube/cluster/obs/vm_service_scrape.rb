# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class VMServiceScrape < Kube::Cluster['VMServiceScrape']
        def initialize(name:, job:, match_name:, port:, &block)
          super() {
            metadata.name  = name
            spec.selector  = { matchLabels: { 'app.kubernetes.io/name' => match_name } }
            spec.endpoints = [{ port: port, relabelConfigs: [{ targetLabel: 'job', replacement: job }] }]
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
