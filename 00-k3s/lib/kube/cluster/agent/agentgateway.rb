# frozen_string_literal: true

module Kube
  module Cluster
    module Agent
      class Agentgateway < Kube::Cluster['Gateway']
        def initialize(name:, port:, &block)
          super() {
            metadata.name         = name
            spec.gatewayClassName = 'agentgateway'
            spec.listeners = [{
              name:     'http',
              port:     port,
              protocol: 'HTTP'
            }]

            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
