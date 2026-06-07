# frozen_string_literal: true

module Kube
  module Cluster
    module Matrix
      class FluffyChat < Kube::Cluster::Manifest
        def initialize(name: "fluffychat", image: "ghcr.io/n-at-han-k/fluffychat:latest", **options)
          deployment = Kube::Cluster["Deployment"].new {
            metadata.name = name
            metadata.labels = { "app" => name }

            spec.replicas = 1
            spec.selector.matchLabels = { "app" => name }

            spec.template.metadata.labels = { "app" => name }
            spec.template.spec.containers = [
              {
                name: "fluffychat",
                image: image,
                ports: [{ containerPort: 8080 }],
                readinessProbe: {
                  httpGet: { path: "/", port: 8080 },
                  initialDelaySeconds: 5,
                  periodSeconds: 5,
                },
                livenessProbe: {
                  httpGet: { path: "/", port: 8080 },
                  initialDelaySeconds: 10,
                  periodSeconds: 10,
                },
              },
            ]
          }

          service = Kube::Cluster["Service"].new {
            metadata.name = name
            metadata.labels = { "app" => name }
            spec.selector = { "app" => name }
            spec.ports = [{ port: 80, targetPort: 8080, protocol: "TCP" }]
          }

          ingress = Kube::Cluster["Ingress"].new {
            metadata.name = name
            metadata.labels = { "app" => name }
            spec.ingressClassName = "traefik"
            spec.rules = [{
              host: "web-chat.kremlin.email",
              http: {
                paths: [{
                  path: "/",
                  pathType: "Prefix",
                  backend: {
                    service: { name: name, port: { number: 80 } },
                  },
                }],
              },
            }]
            spec.tls = [{ hosts: ["web-chat.kremlin.email"] }]
          }

          super(deployment, service, ingress)
        end
      end
    end
  end
end
