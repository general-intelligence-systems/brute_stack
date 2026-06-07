# frozen_string_literal: true

module Kube
  module Cluster
    class Filestash < Kube::Cluster::Manifest
      def initialize(name: "filestash", image: "ghcr.io/n-at-han-k/filestash-webdav-forward-auth:latest", **options)
        secret = Kube::Cluster["Secret"].new {
          metadata.name = name
          stringData["ADMIN_PASSWORD"] = ""
        }

        pvc = Kube::Cluster["PersistentVolumeClaim"].new {
          metadata.name = "#{name}-state"
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
              name: "filestash",
              image: image,
              imagePullPolicy: "Always",
              ports: [{ containerPort: 8334, protocol: "TCP" }],
              env: [
                { name: "FILESTASH_BASE",       value: "/filestash" },
                { name: "APPLICATION_URL",      value: "files.kremlin.email" },
                { name: "WEBDAV_URL",           value: "https://kremlin.email/dav" },
                { name: "OFFICE_URL",           value: "http://office.kremlin.svc.cluster.local:9980" },
                { name: "OFFICE_FILESTASH_URL", value: "https://files.kremlin.email" },
                { name: "OFFICE_REWRITE_URL",   value: "https://files.kremlin.email" },
                {
                  name: "ADMIN_PASSWORD",
                  valueFrom: { secretKeyRef: { name: name, key: "ADMIN_PASSWORD" } },
                },
              ],
              volumeMounts: [
                { name: "state", mountPath: "/app/data/state/" },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "state", persistentVolumeClaim: { claimName: "#{name}-state" } },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.ports = [{ port: 8334, targetPort: 8334, protocol: "TCP" }]
        }

        super(secret, pvc, deployment, service)
      end
    end
  end
end
