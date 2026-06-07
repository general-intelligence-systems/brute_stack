# frozen_string_literal: true

module Kube
  module Cluster
    module Database
      # HelmChart for Neo4j standalone (Community edition).
      #
      # Deployed via the official neo4j/neo4j Helm chart from helm.neo4j.com.
      # Expects an existing Secret (default: "neo4j-auth") containing NEO4J_AUTH
      # in the format "neo4j/<password>".  Pair with Neo4jAuth to provision that
      # secret via ExternalSecrets.
      class Neo4j < Kube::Cluster["HelmChart"]
        CHART_VERSION = "2026.4.0"

        def initialize(
          name: "neo4j",
          chart_version: CHART_VERSION,
          target_namespace: "default",
          storage_size: "10Gi",
          secret_name: "neo4j-auth",
          &block
        )
          super {
            metadata.name = name
            metadata.namespace = "kube-system"
            spec.chart = name
            spec.version = chart_version
            spec.repo = "https://helm.neo4j.com/neo4j"
            spec.targetNamespace = target_namespace
            spec.valuesContent = <<~YAML
              neo4j:
                name: #{name}
                resources:
                  cpu: "500m"
                  memory: "2Gi"
                passwordFromSecret: #{secret_name}

              volumes:
                data:
                  mode: defaultStorageClass
                  defaultStorageClass:
                    requests:
                      storage: #{storage_size}

              services:
                neo4j:
                  spec:
                    type: ClusterIP
            YAML
            instance_exec(&block) if block
          }
        end
      end

      # ExternalSecret that provisions the Neo4j auth secret from the cluster
      # secret store.  The source secret must contain a "NEO4J_AUTH" property
      # with value "neo4j/<password>".
      class Neo4jAuth < Kube::Cluster::Manifest
        def initialize(
          secret_name: "neo4j-auth",
          secret_store: "kubernetes",
          source_secret: "openkrill-neo4j"
        )
          auth_secret = Kube::Cluster["ExternalSecret"].new {
            metadata.name = secret_name
            spec.refreshInterval = "1h"
            spec.secretStoreRef = { kind: "ClusterSecretStore", name: secret_store }
            spec.target = { name: secret_name, creationPolicy: "Owner", deletionPolicy: "Retain" }
            spec.data = [
              {
                secretKey: "NEO4J_AUTH",
                remoteRef: { key: source_secret, property: "NEO4J_AUTH" },
              },
            ]
          }

          super(auth_secret)
        end
      end
    end
  end
end
