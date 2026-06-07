module Kube
  module Cluster
    module Standard
      # Emits a Sandbox resource (agents.x-k8s.io/v1alpha1).
      #
      # The Sandbox controller creates and manages both the Pod and a
      # headless Service automatically, so we do NOT emit our own Service
      # here -- doing so would conflict (ClusterIP vs None is immutable).
      class SandboxWithService < Kube::Cluster::Manifest
        def initialize(
          name:  "ruby",
          image: "ruby:3.3",
          ports:  [3000],
          command: nil,
          env: [],
          probes: {},
          init_containers: [],
          volumes: [],
          volume_mounts: [],
          **options
        )

          container = {
            name: name,
            image: image,
            imagePullPolicy: "Always",
            ports: ports.map { |port|
              { name: "http-#{port}", containerPort: port }
            },
            env: env,
          }

          container[:command] = command if command

          container[:volumeMounts] = volume_mounts unless volume_mounts.empty?
          container[:livenessProbe] = probes[:liveness] if probes[:liveness]
          container[:readinessProbe] = probes[:readiness] if probes[:readiness]
          container[:startupProbe] = probes[:startup] if probes[:startup]

          sandbox = Kube::Cluster["Sandbox"].new {
            metadata.name = name
            metadata.labels = { app: name }

            spec.podTemplate.metadata.labels = { app: name }
            spec.podTemplate.spec.runtimeClassName = "kata-fc"
            spec.podTemplate.spec.restartPolicy = "Always"
            spec.podTemplate.spec.initContainers = init_containers unless init_containers.empty?
            spec.podTemplate.spec.containers = [container]
            spec.podTemplate.spec.volumes = volumes unless volumes.empty?
          }

          super(sandbox)
        end
      end
    end
  end
end
