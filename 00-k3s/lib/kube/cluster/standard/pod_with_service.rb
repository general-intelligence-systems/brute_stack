require "kube/cluster/standard/service"

module Kube
  module Cluster
    module Standard
      class PodWithService < Kube::Cluster::Manifest
        def initialize(
          name:  "ruby",
          image: "ruby:3.3",
          ports:  [3000],
          command: ["sh", "-c", script],
          workingDir: "/app",
          env: [],
          probes: {},
          **options
        )

          resources = []

          resources << Kube::Cluster::Standard::Service.new(
            name: name, ports: ports
          )

          container = {
            name: name,
            image: image,
            workingDir: workingDir,
            command: command,
            ports: ports.map { |port|
              { name: "http-#{port}", containerPort: port }
            },
            env: env,
          }

          container[:livenessProbe] = probes[:liveness] if probes[:liveness]
          container[:readinessProbe] = probes[:readiness] if probes[:readiness]
          container[:startupProbe] = probes[:startup] if probes[:startup]

          resources << Kube::Cluster["Pod"].new {
            metadata.name = name
            metadata.labels = { app: name }

            spec.restartPolicy = "Always"

            spec.containers = [container]
          }

          super(*resources)
        end
      end
    end
  end
end
