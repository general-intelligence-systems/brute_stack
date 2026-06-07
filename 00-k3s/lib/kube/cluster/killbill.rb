# frozen_string_literal: true

module Kube
  module Cluster
    class Killbill < Kube::Cluster::Manifest
      KILLBILL_IMAGE = "killbill/killbill:0.24.16"
      KAUI_IMAGE     = "killbill/kaui:4.0.12"
      DB_HOST        = "postgres-rw.cloudnative-pg.svc.cluster.local"

      def initialize(
        name: "killbill",
        killbill_image: KILLBILL_IMAGE,
        kaui_image: KAUI_IMAGE,
        db_host: DB_HOST,
        admin_user: "admin",
        secret_store: "cnpg-credentials",
        cnpg_app_secret: "postgres-app",
        auth_secret_store: "kubernetes",
        auth_source_secret: "killbill-auth",
        **options
      )
        killbill_version = killbill_image.split(":").last
        kaui_version     = kaui_image.split(":").last

        killbill_labels = {
          "app.kubernetes.io/name"      => name,
          "app.kubernetes.io/instance"  => name,
          "app.kubernetes.io/component" => "api",
        }

        kaui_labels = {
          "app.kubernetes.io/name"      => name,
          "app.kubernetes.io/instance"  => name,
          "app.kubernetes.io/component" => "admin-ui",
        }

        # ── ExternalSecret: Kill Bill database credentials ──────────────
        killbill_db_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "killbill-db"
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: secret_store }
          spec.target = {
            name: "killbill-db",
            creationPolicy: "Owner",
            template: {
              data: {
                KILLBILL_DAO_URL:      "jdbc:postgresql://#{db_host}:5432/killbill",
                KILLBILL_DAO_USER:     "{{ .username }}",
                KILLBILL_DAO_PASSWORD: "{{ .password }}",
              },
            },
          }
          spec.data = [
            { secretKey: "username", remoteRef: { key: cnpg_app_secret, property: "username" } },
            { secretKey: "password", remoteRef: { key: cnpg_app_secret, property: "password" } },
          ]
        }

        # ── ExternalSecret: Kaui database credentials ───────────────────
        kaui_db_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "kaui-db"
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: secret_store }
          spec.target = {
            name: "kaui-db",
            creationPolicy: "Owner",
            template: {
              data: {
                KAUI_CONFIG_DAO_URL:      "jdbc:postgresql://#{db_host}:5432/kaui",
                KAUI_CONFIG_DAO_USER:     "{{ .username }}",
                KAUI_CONFIG_DAO_PASSWORD: "{{ .password }}",
              },
            },
          }
          spec.data = [
            { secretKey: "username", remoteRef: { key: cnpg_app_secret, property: "username" } },
            { secretKey: "password", remoteRef: { key: cnpg_app_secret, property: "password" } },
          ]
        }

        # ── ExternalSecret: shiro.ini auth config ───────────────────────
        auth_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "killbill-auth"
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: auth_secret_store }
          spec.target = { name: "killbill-auth", creationPolicy: "Owner", deletionPolicy: "Retain" }
          spec.data = [
            { secretKey: "shiro.ini", remoteRef: { key: auth_source_secret, property: "shiro.ini" } },
          ]
        }

        # ── Deployment: Kill Bill API server ────────────────────────────
        killbill_deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = killbill_labels

          spec.replicas = 1
          spec.selector.matchLabels = killbill_labels

          spec.template.metadata.labels = killbill_labels
          spec.template.spec.enableServiceLinks = false
          spec.template.spec.restartPolicy = "Always"
          spec.template.spec.containers = [
            {
              name: name,
              image: killbill_image,
              ports: [{ name: "http", containerPort: 8080, protocol: "TCP" }],
              env: [
                { name: "KILLBILL_DAO_URL",      valueFrom: { secretKeyRef: { name: "killbill-db", key: "KILLBILL_DAO_URL" } } },
                { name: "KILLBILL_DAO_USER",     valueFrom: { secretKeyRef: { name: "killbill-db", key: "KILLBILL_DAO_USER" } } },
                { name: "KILLBILL_DAO_PASSWORD", valueFrom: { secretKeyRef: { name: "killbill-db", key: "KILLBILL_DAO_PASSWORD" } } },
                { name: "KILLBILL_SECURITY_SHIRO_RESOURCE_PATH", value: "file:/var/lib/killbill/shiro.ini" },
              ],
              volumeMounts: [
                { name: "shiro-config", mountPath: "/var/lib/killbill/shiro.ini", subPath: "shiro.ini", readOnly: true },
              ],
              livenessProbe: {
                httpGet: { path: "/api.html", port: "http" },
                initialDelaySeconds: 120,
                periodSeconds: 30,
                timeoutSeconds: 5,
              },
              readinessProbe: {
                httpGet: { path: "/api.html", port: "http" },
                initialDelaySeconds: 60,
                periodSeconds: 10,
                timeoutSeconds: 5,
              },
              resources: {
                requests: { cpu: "500m", memory: "2Gi" },
                limits:   { memory: "4Gi" },
              },
            },
          ]
          spec.template.spec.volumes = [
            {
              name: "shiro-config",
              secret: {
                secretName: "killbill-auth",
                items: [{ key: "shiro.ini", path: "shiro.ini" }],
              },
            },
          ]
        }

        # ── Deployment: Kaui admin UI ───────────────────────────────────
        kaui_deployment = Kube::Cluster["Deployment"].new {
          metadata.name = "kaui"
          metadata.labels = kaui_labels

          spec.replicas = 1
          spec.selector.matchLabels = kaui_labels

          spec.template.metadata.labels = kaui_labels
          spec.template.spec.enableServiceLinks = false
          spec.template.spec.restartPolicy = "Always"
          spec.template.spec.containers = [
            {
              name: "kaui",
              image: kaui_image,
              ports: [{ name: "http", containerPort: 8080, protocol: "TCP" }],
              env: [
                { name: "KAUI_CONFIG_DAO_URL",      valueFrom: { secretKeyRef: { name: "kaui-db", key: "KAUI_CONFIG_DAO_URL" } } },
                { name: "KAUI_CONFIG_DAO_USER",     valueFrom: { secretKeyRef: { name: "kaui-db", key: "KAUI_CONFIG_DAO_USER" } } },
                { name: "KAUI_CONFIG_DAO_PASSWORD", valueFrom: { secretKeyRef: { name: "kaui-db", key: "KAUI_CONFIG_DAO_PASSWORD" } } },
                { name: "KAUI_CONFIG_DAO_ADAPTER",  value: "postgresql" },
                { name: "KAUI_KILLBILL_URL",        value: "http://#{name}:8080" },
                { name: "KAUI_ROOT_USERNAME",        value: admin_user },
              ],
              livenessProbe: {
                httpGet: { path: "/", port: "http" },
                initialDelaySeconds: 120,
                periodSeconds: 30,
                timeoutSeconds: 5,
              },
              readinessProbe: {
                httpGet: { path: "/", port: "http" },
                initialDelaySeconds: 60,
                periodSeconds: 10,
                timeoutSeconds: 5,
              },
              resources: {
                requests: { cpu: "200m", memory: "1Gi" },
                limits:   { memory: "2Gi" },
              },
            },
          ]
        }

        # ── Job: Kill Bill database migration ───────────────────────────
        killbill_migrate = Kube::Cluster["Job"].new {
          metadata.name = "killbill-db-migrate"
          metadata.labels = killbill_labels

          spec.backoffLimit = 3
          spec.ttlSecondsAfterFinished = 300
          spec.template.metadata.labels = killbill_labels.merge(
            "app.kubernetes.io/component" => "db-migrate",
          )
          spec.template.spec.restartPolicy = "OnFailure"
          spec.template.spec.containers = [
            {
              name: "migrate",
              image: "postgres:16",
              env: [
                { name: "KILLBILL_VERSION", value: killbill_version },
                { name: "PGPASSWORD", valueFrom: { secretKeyRef: { name: "killbill-db", key: "KILLBILL_DAO_PASSWORD" } } },
                { name: "PGHOST",     value: db_host },
                { name: "PGUSER",     value: "app" },
                { name: "PGDATABASE", value: "killbill" },
              ],
              command: ["bash", "-exc", <<~'SCRIPT'],
                apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1
                DDL_URL="https://docs.killbill.io/latest/ddl.sql"
                echo "Fetching DDL from $DDL_URL"
                DDL=$(curl -fSsL "$DDL_URL")
                DDL=$(echo "$DDL" \
                  | sed 's/datetime/timestamp/gi' \
                  | sed 's|/\*!.*\*/||g' \
                  | sed 's/unsigned//gi' \
                  | sed 's/mediumtext/text/gi' \
                  | sed 's/mediumblob/bytea/gi' \
                  | sed 's/ blob / bytea /gi' \
                  | sed '/^[Dd][Rr][Oo][Pp] [Tt][Aa][Bb][Ll][Ee] /d')
                DDL=$(echo "$DDL" \
                  | sed 's/CREATE TABLE /CREATE TABLE IF NOT EXISTS /gi' \
                  | sed 's/CREATE UNIQUE INDEX /CREATE UNIQUE INDEX IF NOT EXISTS /gi' \
                  | sed 's/CREATE INDEX /CREATE INDEX IF NOT EXISTS /gi')
                echo "$DDL" | psql -v ON_ERROR_STOP=1
                echo "Migration complete"
              SCRIPT
            },
          ]
        }

        # ── Job: Kaui database migration ────────────────────────────────
        kaui_migrate = Kube::Cluster["Job"].new {
          metadata.name = "kaui-db-migrate"
          metadata.labels = kaui_labels

          spec.backoffLimit = 3
          spec.ttlSecondsAfterFinished = 300
          spec.template.metadata.labels = kaui_labels.merge(
            "app.kubernetes.io/component" => "db-migrate",
          )
          spec.template.spec.restartPolicy = "OnFailure"
          spec.template.spec.containers = [
            {
              name: "migrate",
              image: "postgres:16",
              env: [
                { name: "KAUI_VERSION", value: kaui_version },
                { name: "PGPASSWORD", valueFrom: { secretKeyRef: { name: "kaui-db", key: "KAUI_CONFIG_DAO_PASSWORD" } } },
                { name: "PGHOST",     value: db_host },
                { name: "PGUSER",     value: "app" },
                { name: "PGDATABASE", value: "kaui" },
              ],
              command: ["bash", "-exc", <<~'SCRIPT'],
                apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1
                DDL_URL="https://raw.githubusercontent.com/killbill/killbill-admin-ui/v$KAUI_VERSION/db/ddl.sql"
                echo "Fetching DDL from $DDL_URL"
                DDL=$(curl -fSsL "$DDL_URL")
                DDL=$(echo "$DDL" \
                  | sed 's/datetime/timestamp/gi' \
                  | sed 's|/\*!.*\*/||g' \
                  | sed 's/unsigned//gi' \
                  | sed 's/mediumtext/text/gi' \
                  | sed 's/mediumblob/bytea/gi' \
                  | sed 's/ blob / bytea /gi')
                DDL=$(echo "$DDL" \
                  | sed 's/CREATE TABLE /CREATE TABLE IF NOT EXISTS /gi' \
                  | sed 's/CREATE UNIQUE INDEX /CREATE UNIQUE INDEX IF NOT EXISTS /gi' \
                  | sed 's/CREATE INDEX /CREATE INDEX IF NOT EXISTS /gi')
                echo "$DDL" | psql -v ON_ERROR_STOP=1
                echo "Migration complete"
              SCRIPT
            },
          ]
        }

        # ── Service: Kill Bill API ──────────────────────────────────────
        killbill_service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = killbill_labels
          spec.selector = killbill_labels
          spec.ports = [{ name: "http", port: 8080, targetPort: "http", protocol: "TCP" }]
        }

        # ── Service: Kaui admin UI ──────────────────────────────────────
        kaui_service = Kube::Cluster["Service"].new {
          metadata.name = "kaui"
          metadata.labels = kaui_labels
          spec.selector = kaui_labels
          spec.ports = [{ name: "http", port: 9090, targetPort: "http", protocol: "TCP" }]
        }

        super(
          killbill_db_secret,
          kaui_db_secret,
          auth_secret,
          killbill_deployment,
          kaui_deployment,
          killbill_migrate,
          kaui_migrate,
          killbill_service,
          kaui_service,
        )
      end
    end
  end
end
