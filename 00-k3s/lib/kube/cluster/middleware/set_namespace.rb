# frozen_string_literal: true

require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Sets +metadata.namespace+ on all namespace-scoped resources,
      # skipping HelmCharts and resources that already have a
      # non-default namespace set.
      #
      #   use SetNamespace, 'authelia'
      #
      class SetNamespace < Middleware
        def initialize(namespace)
          super(filter: ->(r) { r.kind != 'HelmChart' })
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! { |resource|
            filter(resource) {
              next resource if resource.cluster_scoped?

              h = resource.to_h
              h[:metadata] ||= {}
              next resource if h[:metadata][:namespace] && h[:metadata][:namespace] != 'default'

              h[:metadata][:namespace] = @namespace
              resource.rebuild(h)
            }
          }
        end
      end
    end
  end
end
