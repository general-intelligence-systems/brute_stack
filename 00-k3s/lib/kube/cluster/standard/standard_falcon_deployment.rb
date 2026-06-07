module Kube
  module Cluster
    module Standard
      class FalconDeployment < DeploymentWithService
        def initialize(name:, image:, port: 3000, env: [], **options, &block)
          super(
            name: name, image: image, port: port, env: env,
            readiness_probe: {
              httpGet: { path: "/ping", port: port },
              initialDelaySeconds: 5,
              periodSeconds: 5,
            },
            liveness_probe: {
              httpGet: { path: "/ping", port: port },
              initialDelaySeconds: 10,
              periodSeconds: 10,
            },
            **options, &block
          )
        end
      end
    end
  end
end
