# frozen_string_literal: true

module Kube
  module Cluster
    class NixosWorkstation < Kube::Cluster::Manifest
      def initialize(name:, namespace:, image: "nixos/nix:latest", storage: "10Gi", storage_class: "local-path")
        ns = Kube::Cluster["Namespace"].new {
          metadata.name = namespace
          metadata.labels = { "type" => "workspace" }
        }

        statefulset = Kube::Cluster["StatefulSet"].new {
          metadata.name = name
          metadata.namespace = namespace
          metadata.labels = { "app" => name }

          spec.serviceName = name
          spec.replicas = 1
          spec.selector.matchLabels = { "app" => name }

          spec.template.metadata.labels = { "app" => name }
          spec.template.spec.containers = [
            Kube::Cluster::Container.new(
              name: "nixos",
              image: image,
              command: ["sleep", "infinity"],
              volumeMounts: [
                { name: "data", mountPath: "/data" },
              ],
            ),
          ]

          spec.volumeClaimTemplates = [
            {
              metadata: { name: "data" },
              spec: {
                accessModes: ["ReadWriteOnce"],
                storageClassName: storage_class,
                resources: { requests: { storage: storage } },
              },
            },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.namespace = namespace
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.clusterIP = "None"
          spec.ports = [{ name: "ssh", port: 22, targetPort: 22, protocol: "TCP" }]
        }

        super(ns, statefulset, service)
      end
    end
  end
end
