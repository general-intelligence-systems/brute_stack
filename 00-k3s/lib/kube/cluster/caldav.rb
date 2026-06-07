# frozen_string_literal: true

module Kube
  module Cluster
    class Caldav < Kube::Cluster::Manifest
      def initialize(name: "caldav", image: "ghcr.io/general-intelligence-systems/async-caldav:main", **options)
        pvc = Kube::Cluster["PersistentVolumeClaim"].new {
          metadata.name = "#{name}-data"
          spec.accessModes = ["ReadWriteOnce"]
          spec.storageClassName = "local-path"
          spec.resources = { requests: { storage: "1Gi" } }
        }

        deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = { "app" => name }

          spec.replicas = 1
          spec.selector.matchLabels = { "app" => name }

          spec.template.metadata.labels = { "app" => name }
          spec.template.spec.containers = [
            {
              name: "caldav",
              image: image,
              imagePullPolicy: "Always",
              ports: [{ containerPort: 9292, protocol: "TCP" }],
              #resources: {
              #  requests: { memory: "64Mi", cpu: "50m" },
              #  limits: { memory: "256Mi" },
              #},
              volumeMounts: [
                { name: "data", mountPath: "/data" },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "data", persistentVolumeClaim: { claimName: "#{name}-data" } },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.ports = [{ port: 9292, targetPort: 9292, protocol: "TCP" }]
        }

        super(pvc, deployment, service)
      end
    end
  end
end
