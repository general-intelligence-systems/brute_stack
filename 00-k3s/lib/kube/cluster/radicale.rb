# frozen_string_literal: true

module Kube
  module Cluster
    class Radicale < Kube::Cluster::Manifest
      def initialize(name: "radicale", image: "tomsquest/docker-radicale:latest", **options)
        external_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "#{name}-htpasswd"
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: "kubernetes" }
          spec.target = { name: "#{name}-htpasswd", creationPolicy: "Owner", deletionPolicy: "Retain" }
          spec.data = [
            {
              secretKey: "users",
              remoteRef: { key: "openkrill-radicale", property: "htpasswd" },
            },
          ]
        }

        config = Kube::Cluster["ConfigMap"].new {
          metadata.name = "#{name}-config"
          data["config"] = <<~CONFIG
            [server]
            hosts = 0.0.0.0:5232

            [auth]
            type = htpasswd
            htpasswd_filename = /config/users
            htpasswd_encryption = bcrypt

            [storage]
            filesystem_folder = /data/collections
          CONFIG
        }

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
          spec.template.spec.securityContext = {
            runAsUser: 2999,
            runAsGroup: 2999,
            fsGroup: 2999,
          }
          spec.template.spec.containers = [
            {
              name: "radicale",
              image: image,
              ports: [{ containerPort: 5232, protocol: "TCP" }],
              securityContext: {
                readOnlyRootFilesystem: true,
                allowPrivilegeEscalation: false,
                capabilities: {
                  drop: ["ALL"],
                  add: ["CHOWN", "SETUID", "SETGID", "KILL"],
                },
              },
              resources: {
                requests: { memory: "64Mi", cpu: "50m" },
                limits: { memory: "256Mi" },
              },
              livenessProbe: {
                httpGet: { path: "/", port: 5232 },
                initialDelaySeconds: 10,
                periodSeconds: 30,
                failureThreshold: 3,
              },
              readinessProbe: {
                httpGet: { path: "/", port: 5232 },
                initialDelaySeconds: 5,
                periodSeconds: 15,
                failureThreshold: 2,
              },
              volumeMounts: [
                { name: "data", mountPath: "/data" },
                { name: "config", mountPath: "/config/config", subPath: "config", readOnly: true },
                { name: "htpasswd", mountPath: "/config/users", subPath: "users", readOnly: true },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "data", persistentVolumeClaim: { claimName: "#{name}-data" } },
            { name: "config", configMap: { name: "#{name}-config" } },
            { name: "htpasswd", secret: { secretName: "#{name}-htpasswd" } },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.ports = [{ port: 5232, targetPort: 5232, protocol: "TCP" }]
        }

        super(external_secret, config, pvc, deployment, service)
      end
    end
  end
end
