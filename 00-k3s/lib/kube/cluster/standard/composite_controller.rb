require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class CompositeController < Kube::Cluster['CompositeController']
        def initialize(name:, webhook_url:, resync_period: 30, parent_resource:, child_resources: {}, &block)
          resolved_parent   = resolve_ref(parent_resource)
          resolved_children = resolve_hash(child_resources)

          super() {
            metadata.name = "#{name}-composite-controller"

            spec.generateSelector    = true
            spec.resyncPeriodSeconds = resync_period
            spec.hooks.sync.webhook  = { url: webhook_url }
            spec.parentResource      = resolved_parent
            spec.childResources      = resolved_children

            instance_exec(&block) if block
          }
        end

        private

        def resolve_ref(ref)
          return ref if ref.is_a?(Hash)

          klass = ref.is_a?(Class) ? ref : ref.class
          {
            apiVersion: klass.defaults['apiVersion'],
            resource:   klass.defaults['kind'].downcase.pluralize
          }
        end

        def resolve_hash(hash)
          hash.map { |klass, options|
            resolve_ref(klass).merge(options || {})
          }
        end
      end
    end
  end
end
