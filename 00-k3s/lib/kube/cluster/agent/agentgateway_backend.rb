# frozen_string_literal: true

module Kube
  module Cluster
    module Agent
      class AgentgatewayBackend < Kube::Cluster['AgentgatewayBackend']
        def initialize(name:, model:, host:, port:, provider: :openai, &block)
          super() do
            metadata.name = name
            spec.ai = {
              groups: [
                {
                  providers: [
                    {
                      name: name,
                      host: host,
                      port: port,
                      provider => { model: model }
                    }
                  ]
                }
              ]
            }
            instance_exec(&block) if block
          end
        end
      end
    end
  end
end
