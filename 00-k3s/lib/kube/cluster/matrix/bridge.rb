# frozen_string_literal: true

module Kube
  module Cluster
    module Matrix
      class Bridge < Kube::Cluster::Manifest
        AS_TOKEN = "956a8cd58dd8420649717fade3974590641594a8f59989c2c00b1e68a427a56a"
        HS_TOKEN = "51013f109db594670d083539775bae41fdae8da9aae53df115906b957ef60464"

        # Appservice registration ConfigMap for Synapse — must live in the
        # matrix-stack namespace so Synapse can mount it.  This is a separate
        # class because it must NOT pass through the Namespace middleware that
        # rewrites everything to ai.
        class Registration < Kube::Cluster["ConfigMap"]
          def initialize(name: "matrix-bridge")
            super() {
              metadata.name = "#{name}-registration"
              metadata.namespace = "matrix-stack"
              self.data = {
                "registration.yaml" => <<~YAML
                  id: #{name}
                  url: "http://#{name}.ai.svc.cluster.local:3000"
                  as_token: "#{AS_TOKEN}"
                  hs_token: "#{HS_TOKEN}"
                  sender_localpart: bot
                  namespaces:
                    users:
                      - exclusive: true
                        regex: "@bot:chat\\\\.kremlin\\\\.email"
                YAML
              }
            }
          end
        end

        def initialize(
          name: "matrix-bridge",
          image: "registry.cia.net/matrix-bridge:latest",
          **options
        )

          config = Kube::Cluster["ConfigMap"].new {
            metadata.name = "#{name}-config"
            self.data = {
              "AS_TOKEN" => AS_TOKEN,
              "HS_TOKEN" => HS_TOKEN,
            }
          }

          deployment = Kube::Cluster["Deployment"].new {
            metadata.name = name
            metadata.labels = { "app" => name }

            spec.replicas = 1
            spec.selector.matchLabels = { "app" => name }

            spec.template.metadata.labels = { "app" => name }
            spec.template.spec.containers = [
              {
                name: "matrix-bridge",
                image: image,
                ports: [{ containerPort: 3000 }],
                envFrom: [{ configMapRef: { name: "#{name}-config" } }],
                readinessProbe: {
                  tcpSocket: { port: 3000 },
                  initialDelaySeconds: 5,
                  periodSeconds: 5,
                },
                livenessProbe: {
                  tcpSocket: { port: 3000 },
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
            spec.ports = [{ port: 3000, targetPort: 3000, protocol: "TCP" }]
          }

          super(config, deployment, service)
        end
      end
    end
  end
end
