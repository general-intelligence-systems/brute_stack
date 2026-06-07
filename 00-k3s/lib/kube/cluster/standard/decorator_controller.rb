require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class DecoratorController < Kube::Cluster['DecoratorController']
        def initialize(name:, webhook_url:, resync_period: 30, resources: {}, attachments: {}, &block)
          resolved_resources   = resolve_hash(resources)
          resolved_attachments = resolve_hash(attachments)

          super() {
            metadata.name = name

            spec.resources           = resolved_resources
            spec.attachments         = resolved_attachments
            spec.resyncPeriodSeconds = resync_period
            spec.hooks.sync.webhook  = { url: webhook_url }

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
