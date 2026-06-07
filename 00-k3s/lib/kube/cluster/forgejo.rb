# frozen_string_literal: true

module Kube
  module Cluster
    class Forgejo < Kube::Cluster["HelmChart"]
      CHART_VERSION = "16.2.1"
      DOMAIN        = "git.cia.net"

      def initialize(
        domain: DOMAIN,
        chart_version: CHART_VERSION,
        target_namespace: "default",
        storage_size: "200Gi",
        storage_class: "local-path",
        node_selector: "herman-goering",
        &block
      )
        super {
          metadata.name = "forgejo"
          metadata.namespace = "kube-system"
          spec.version = chart_version
          spec.chart = "oci://codeberg.org/forgejo-contrib/forgejo"
          spec.targetNamespace = target_namespace
          spec.valuesContent = <<~YAML
            gitea:
              config:
                server:
                  ROOT_URL: https://#{domain}/
                  DOMAIN: #{domain}
                  SSH_DOMAIN: #{domain}
                security:
                  INSTALL_LOCK: true
                  REVERSE_PROXY_AUTHENTICATION_USER: Remote-User
                  REVERSE_PROXY_AUTHENTICATION_EMAIL: Remote-Email
                service:
                  ENABLE_REVERSE_PROXY_AUTHENTICATION: true
                  ENABLE_REVERSE_PROXY_AUTO_REGISTRATION: true
                  ENABLE_REVERSE_PROXY_EMAIL: true
                  DISABLE_REGISTRATION: true
                  ALLOW_ONLY_EXTERNAL_REGISTRATION: true
                openid:
                  ENABLE_OPENID_SIGNIN: false
                oauth2:
                  ENABLED: true
                actions:
                  ENABLED: true
                  DEFAULT_ACTIONS_URL: self
                migrations:
                  HTTP_CLIENT_TIMEOUT: 3600
                  MAX_ATTEMPTS: 5
                git.timeout:
                  CLONE: 3600
                  MIGRATE: 3600
                repository:
                  MAX_CREATION_LIMIT: -1
                metrics:
                  ENABLED: "true"
            persistence:
              enabled: true
              size: #{storage_size}
              storageClass: #{storage_class}
            #{node_selector ? "nodeSelector:\n  kubernetes.io/hostname: #{node_selector}" : ""}
          YAML
          instance_exec(&block) if block
        }
      end
    end
  end
end
