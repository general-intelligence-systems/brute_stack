# frozen_string_literal: true

require "kube/cluster/standard/deployment_with_service"
require "kube/cluster/standard/postgres_database"

module Kube
  module Cluster
    class Operaton < Kube::Cluster::Manifest
      IMAGE = "operaton/operaton:1.0.3"

      def initialize(name: "operaton", namespace: "default", &block)
        database = Standard::PostgresDatabase.new(name: name)

        deployment_with_service = Standard::DeploymentWithService.new(
          name: name, image: IMAGE, port: 8080,
          namespace: namespace,
          env: [
            { name: "DB_DRIVER",   value: "org.postgresql.Driver" },
            { name: "DB_URL",      valueFrom: { secretKeyRef: { name: "#{name}-db", key: "DB_URL" } } },
            { name: "DB_USERNAME", valueFrom: { secretKeyRef: { name: "#{name}-db", key: "DB_USER" } } },
            { name: "DB_PASSWORD", valueFrom: { secretKeyRef: { name: "#{name}-db", key: "DB_PASSWORD" } } },
          ],
          pod_security_context: { fsGroup: 1000 },
          security_context: {
            runAsNonRoot: true,
            runAsUser: 1000,
            capabilities: { drop: ["ALL"] },
          },
          resources: {
            requests: { cpu: "250m", memory: "512Mi" },
            limits: { cpu: "1", memory: "1Gi" },
          },
          readiness_probe: {
            httpGet: { path: "/operaton/", port: "http" },
            initialDelaySeconds: 30,
            periodSeconds: 10,
            failureThreshold: 3,
          },
        )

        super(database, deployment_with_service)
        instance_exec(&block) if block
      end
    end
  end
end
