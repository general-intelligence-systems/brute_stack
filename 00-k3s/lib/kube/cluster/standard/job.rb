require 'kube/cluster/standard/env_processing'

module Kube
  module Cluster
    module Standard
      class Job < Kube::Cluster['Job']
        def initialize(name:, image:, env: {}, command: nil, backoff_limit: 3, ttl: 300, &block)
          processed_env = EnvProcessing.process(env)

          super() do
            metadata.name = name

            spec.backoffLimit = backoff_limit
            spec.ttlSecondsAfterFinished = ttl
            spec.template.spec.restartPolicy = 'OnFailure'

            container = {
              name: name,
              image: image,
              env: processed_env
            }
            container[:command] = command if command

            spec.template.spec.containers = [container]

            instance_exec(&block) if block
          end
        end
      end
    end
  end
end
