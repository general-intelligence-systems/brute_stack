# frozen_string_literal: true

module Kube
  module Cluster
    class ForgejoRunner < Kube::Cluster::Manifest
      RUNNER_IMAGE   = "code.forgejo.org/forgejo/runner:12.8.2"
      FORGEJO_URL    = "http://forgejo-http.default.svc.cluster.local:3000"
      CA_BUNDLE_CM   = "openkrill-ca-bundle"
      CA_BUNDLE_KEY  = "bundle.pem"
      DIND_CA_PATH   = "/etc/ssl/certs/ca-certificates.crt"
      JOB_CA_PATH    = "/openkrill-ca-bundle.crt"

      # Default runner definitions matching the live cluster.
      DEFAULT_RUNNERS = {
        "nix-runner" => {
          labels: ["nix:docker://ghcr.io/general-intelligence-systems/runs-on-nix:latest"],
          secret_name: "nix-runner-secret",
          source_secret: "openkrill-nix-runner-secret",
        },
        "ubuntu-runner" => {
          labels: [
            "ubuntu:docker://node:20-bookworm",
            "docker:docker://node:20-bookworm",
          ],
          secret_name: "ubuntu-runner-secret",
          source_secret: "openkrill-ubuntu-runner-secret",
        },
      }.freeze

      def initialize(
        runners: DEFAULT_RUNNERS,
        replicas: 0,
        runner_image: RUNNER_IMAGE,
        forgejo_url: FORGEJO_URL,
        ca_bundle_configmap: CA_BUNDLE_CM,
        ca_bundle_key: CA_BUNDLE_KEY,
        insecure_registries: %w[
          forgejo-http.default.svc.cluster.local:3000
          docker-registry.docker-registry.svc.cluster.local:5000
        ],
        **options
      )
        resources = runners.flat_map do |name, runner|
          build_runner(
            name: name,
            labels: runner[:labels],
            secret_name: runner[:secret_name],
            source_secret: runner[:source_secret],
            replicas: replicas,
            runner_image: runner_image,
            forgejo_url: forgejo_url,
            ca_bundle_configmap: ca_bundle_configmap,
            ca_bundle_key: ca_bundle_key,
            insecure_registries: insecure_registries,
          )
        end

        super(*resources)
      end

      private

      def build_runner(name:, labels:, secret_name:, source_secret:, replicas:, runner_image:, forgejo_url:, ca_bundle_configmap:, ca_bundle_key:, insecure_registries:)
        config_name = "#{name}-config"

        label_lines = labels.map { |l| "    - \"#{l}\"" }.join("\n")
        config_yaml = <<~YAML
          runner:
            labels:
          #{label_lines}
            envs:
              DOCKER_HOST: tcp://localhost:2375
          container:
            network: "host"
            docker_host: "tcp://localhost:2375"
            options: "--device /dev/kvm -v #{DIND_CA_PATH}:#{JOB_CA_PATH}:ro"
            valid_volumes:
              - "**"
        YAML

        # ── ExternalSecret for runner registration token ──────────────
        external_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = secret_name
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: "kubernetes" }
          spec.target = { name: secret_name, creationPolicy: "Owner", deletionPolicy: "Retain" }
          spec.data = [
            { secretKey: "secret", remoteRef: { key: source_secret, property: "secret" } },
          ]
        }

        # ── ConfigMap with runner config.yaml ─────────────────────────
        config = Kube::Cluster["ConfigMap"].new {
          metadata.name = config_name
          data["config.yaml"] = config_yaml
        }

        # ── Deployment: runner + DinD sidecar ─────────────────────────
        dind_command = ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]
        insecure_registries.each { |r| dind_command.push("--insecure-registry=#{r}") }

        deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = { "app" => name }

          spec.replicas = replicas
          spec.selector.matchLabels = { "app" => name }

          spec.template.metadata.labels = { "app" => name }
          spec.template.spec.containers = [
            {
              name: "dind",
              image: "docker:dind",
              securityContext: { privileged: true },
              command: dind_command,
              volumeMounts: [
                { name: "ca-bundle", mountPath: DIND_CA_PATH, subPath: ca_bundle_key },
              ],
            },
            {
              name: "runner",
              image: runner_image,
              command: ["/bin/sh", "-c"],
              args: [
                <<~SCRIPT
                  set -e
                  sleep 5
                  forgejo-runner create-runner-file \
                    --instance "${FORGEJO_URL}" \
                    --name "#{name}" \
                    --secret "${RUNNER_SECRET}"
                  forgejo-runner daemon --config /etc/runner/config.yaml
                SCRIPT
              ],
              env: [
                { name: "FORGEJO_URL", value: forgejo_url },
                { name: "RUNNER_SECRET", valueFrom: { secretKeyRef: { name: secret_name, key: "secret" } } },
                { name: "DOCKER_HOST", value: "tcp://localhost:2375" },
              ],
              volumeMounts: [
                { name: "config", mountPath: "/etc/runner/config.yaml", subPath: "config.yaml" },
                { name: "ca-bundle", mountPath: DIND_CA_PATH, subPath: ca_bundle_key },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "config", configMap: { name: config_name } },
            { name: "ca-bundle", configMap: { name: ca_bundle_configmap } },
          ]
        }

        [external_secret, config, deployment]
      end
    end
  end
end
