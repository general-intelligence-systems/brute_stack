# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class PersesDatasource < Kube::Cluster['PersesDatasource']
        def initialize(name:, plugin_kind:, url:, display_name: nil, default: false, &block)
          super() {
            metadata.name = name
            spec.config = {
              default: default,
              display: { name: display_name || name },
              plugin: {
                kind: plugin_kind,
                spec: {
                  proxy: {
                    kind: 'HTTPProxy',
                    spec: { url: url },
                  },
                },
              },
            }
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
