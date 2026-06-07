# frozen_string_literal: true

require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Adds +reloader.stakater.com/auto: "true"+ to Deployments,
      # StatefulSets, and DaemonSets so Stakater Reloader triggers
      # rolling restarts when referenced ConfigMaps or Secrets change.
      #
      #   use SetReloaderAuto
      #
      class SetReloaderAuto < Middleware
        KINDS = %w[Deployment StatefulSet DaemonSet].freeze

        def initialize
          super(filter: ->(r) { KINDS.include?(r.kind) })
        end

        def call(manifest)
          manifest.resources.map! { |resource|
            filter(resource) {
              h = resource.to_h
              h[:metadata] ||= {}
              h[:metadata][:annotations] ||= {}
              h[:metadata][:annotations][:'reloader.stakater.com/auto'] = 'true'
              resource.rebuild(h)
            }
          }
        end
      end
    end
  end
end
