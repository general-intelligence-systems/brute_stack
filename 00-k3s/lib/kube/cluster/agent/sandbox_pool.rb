module Kube
  module Cluster
    module Agent
      class SandboxPool < Kube::Cluster::Manifest
        attr_reader :manifest

        def initialize(replicas: 5, image:, name: "", egress: [], env: [], **options)
          container = Container.new(
            name: "runner",
            image: image,
            env: env,
            ports: [{containerPort: 8080}],
            readinessProbe: {
              httpGet: { path: "/ping", port: 8080 },
              initialDelaySeconds: 5,
              periodSeconds: 5,
            },
            startupProbe: {
              httpGet: { path: "/ping", port: 8080 },
              initialDelaySeconds: 5,
              periodSeconds: 5,
              failureThreshold: 12,
            },
            livenessProbe: {
              httpGet: { path: "/ping", port: 8080 },
              initialDelaySeconds: 5,
              periodSeconds: 10,
            },
          )

          if name.present?
            name = "#{name}-"
          else
            name = ""
          end

          # The managed network policy blocks all private IP ranges by default.
          # Always allow cluster DNS so pods can resolve the oci_artifact ref
          # and any other cluster-internal names.  Callers pass additional
          # egress rules (e.g. registry access) via the egress: parameter.
          dns_egress = {
            to: [{ namespaceSelector: { matchLabels: { "kubernetes.io/metadata.name" => "kube-system" } },
                    podSelector: { matchLabels: { "k8s-app" => "kube-dns" } } }],
            ports: [
              { protocol: "UDP", port: 53 },
              { protocol: "TCP", port: 53 },
            ],
          }
          all_egress = [dns_egress] + egress

          sandbox_template =
            Kube::Cluster["SandboxTemplate"].new {
              metadata.name = "#{name}sandbox-template"

              spec.networkPolicy.egress = all_egress

              spec.podTemplate.spec.dnsPolicy = "ClusterFirst"
              spec.podTemplate.spec.securityContext.runAsNonRoot = true
              spec.podTemplate.spec.securityContext.runAsUser = 1000
              spec.podTemplate.spec.runtimeClassName = "kata-fc"
              spec.podTemplate.spec.nodeSelector.runtime = "kata-fc"
              spec.podTemplate.spec.tolerations = [
                { key: "fc-only", value: "true", effect: "NoSchedule" }
              ]
              spec.podTemplate.spec.automountServiceAccountToken = false
              spec.podTemplate.spec.containers = [ container ]
            }

          sandbox_warm_pool =
            Kube::Cluster["SandboxWarmPool"].new {
              metadata.name = "#{name}sandbox-warm-pool"

              spec.sandboxTemplateRef.name = sandbox_template.to_h.metadata.name
              spec.replicas = replicas
            }

          super(
            sandbox_template,
            sandbox_warm_pool,
          )
        end
      end
    end
  end
end
