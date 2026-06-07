# frozen_string_literal: true

module Kube
  module Cluster
    module Agent
      class AgentgatewayRoute < Kube::Cluster['HTTPRoute']
        def initialize(name:, gateway:, backend:, namespace:, &block)
          super() {
            metadata.name = name
            spec.parentRefs = [{
              name:      gateway,
              namespace: namespace
            }]
            spec.rules = [{
              backendRefs: [{
                name:      backend,
                namespace: namespace,
                group:     'agentgateway.dev',
                kind:      'AgentgatewayBackend'
              }]
            }]
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
