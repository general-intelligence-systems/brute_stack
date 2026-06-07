module Kube
  module Cluster
    module Standard
      class PostgresExternalSecret < Kube::Cluster["ExternalSecret"]
        DB_HOST = "postgres-rw.cloudnative-pg.svc.cluster.local"

        def initialize(name:, env_prefix: "DB", db_host: DB_HOST, &block)
          super() {
            metadata.name = "#{name}-db"
            spec.refreshInterval = "1h"
            spec.secretStoreRef = { kind: "ClusterSecretStore", name: "cnpg-credentials" }
            spec.target = {
              name: "#{name}-db",
              creationPolicy: "Owner",
              deletionPolicy: "Retain",
              template: {
                data: {
                  "#{env_prefix}_URL"      => "jdbc:postgresql://#{db_host}:5432/#{name}",
                  "#{env_prefix}_USER"     => "{{ .username }}",
                  "#{env_prefix}_PASSWORD" => "{{ .password }}",
                },
              },
            }
            spec.data = [
              { secretKey: "username", remoteRef: { key: "postgres-app", property: "username" } },
              { secretKey: "password", remoteRef: { key: "postgres-app", property: "password" } },
            ]
            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end
