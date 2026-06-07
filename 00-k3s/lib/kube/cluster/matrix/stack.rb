# frozen_string_literal: true

require "yaml"

module Kube
  module Cluster
    module Matrix
      class Stack < Kube::Cluster["HelmChart"]
        AGENTS_DIR = File.expand_path("../../../../ns/ai/agents", __dir__)

        def initialize(&block)
          appservices = agent_appservices

          super {
            metadata.name = "matrix-stack"
            metadata.namespace = "kube-system"
            spec.chart = "oci://ghcr.io/element-hq/ess-helm/matrix-stack"
            spec.version = "26.3.0"
            spec.targetNamespace = "kremlin"
            spec.createNamespace = false
            spec.valuesContent = {
              "serverName" => "chat.kremlin.email",

              "ingress" => { "className" => "traefik" },

              "synapse" => {
                "ingress" => { "host" => "chat.kremlin.email" },
                "media" => { "storage" => { "storageClassName" => "local-path" } },
                "nodeSelector" => { "kubernetes.io/hostname" => "herman-goering" },
                "appservices" => appservices,
                "postgres" => {
                  "host" => "postgres-rw.cloudnative-pg.svc.cluster.local",
                  "port" => 5432,
                  "user" => "app",
                  "database" => "synapse",
                  "sslMode" => "disable",
                  "password" => {
                    "secret" => "synapse-db",
                    "secretKey" => "DB_PASSWORD",
                  },
                },
              },
              "postgres" => { "enabled" => false },
              "elementWeb" => { "enabled" => false },

              "matrixAuthenticationService" => {
                "ingress" => { "host" => "auth-chat.kremlin.email" },
                "postgres" => {
                  "host" => "postgres-rw.cloudnative-pg.svc.cluster.local",
                  "port" => 5432,
                  "user" => "app",
                  "database" => "mas",
                  "sslMode" => "disable",
                  "password" => {
                    "secret" => "mas-db",
                    "secretKey" => "DB_PASSWORD",
                  },
                },
                "additional" => {
                  "0-sso" => {
                    "config" => <<~YAML
                      upstream_oauth2:
                        providers:
                          - id: 0870CA2BF7272852F5DAB70319
                            human_name: Authelia
                            issuer: "https://auth.kremlin.email"
                            client_id: "matrix-authentication-service"
                            client_secret: "matrix-authentication-service-oidc-client-secret-kremlin.email"
                            token_endpoint_auth_method: client_secret_basic
                            scope: "openid profile email"
                            discovery_mode: insecure
                            fetch_userinfo: true
                            claims_imports:
                              skip_confirmation: true
                              localpart:
                                action: require
                                template: "{{ user.preferred_username }}"
                              displayname:
                                action: force
                                template: "{{ user.name }}"
                              email:
                                action: force
                                template: "{{ user.email }}"
                      passwords:
                        enabled: false
                    YAML
                  },
                },
              },

              "elementAdmin" => {
                "ingress" => { "host" => "admin-chat.kremlin.email" }
              },

              "matrixRTC" => { "enabled" => false },

              "wellKnownDelegation" => { "enabled" => true },
            }.to_yaml

            instance_exec(&block) if block
          }
        end

        private

          def agent_appservices
            Dir.glob("#{AGENTS_DIR}/*/")
              .select { |d| File.directory?(d) }
              .map { |d| File.basename(d) }
              .map { |name|
                {
                  "secret" => "agent-#{name}-matrix",
                  "secretKey" => "registration.yaml"
                }
              }
          end
      end
    end
  end
end
