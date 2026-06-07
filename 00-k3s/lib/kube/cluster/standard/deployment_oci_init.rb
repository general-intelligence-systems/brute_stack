module Kube
  module Cluster
    module Standard
      class DeploymentOciInit < Kube::Cluster::Manifest
        def initialize
          super(
            Kube::Cluster["Deployment"].new {
              metadata.name = "ruby-app"
              metadata.labels = { app: "ruby-app" }

              spec.replicas = 2
              spec.selector.matchLabels = { app: "ruby-app" }

              spec.template.spec.imagePullSecrets = [{ name: "oci-registry-creds" }]

              spec.template.spec.initContainers = [
                Kube::Cluster::Container.new(
                  name: "fetch-oci-artifact",
                  image: "ghcr.io/oras-project/oras:v1.2.3",
                  command: ["sh", "-c", <<~SH],
                    set -euo pipefail
                    cd /artifact
                    oras pull "$ARTIFACT_REF"
                    echo "Pulled artifact contents:"
                    ls -la /artifact
                  SH
                  env: [{ name: "ARTIFACT_REF", value: "registry.example.com/my-org/my-artifact:v1.0.0" }],
                  volumeMounts: [
                    { name: "artifact-data", mountPath: "/artifact" },
                    { name: "docker-config", mountPath: "/root/.docker", readOnly: true },
                  ],
                )
              ]

              spec.template.spec.containers = [
                Kube::Cluster::Container.new(
                  name: "ruby",
                  image: "ruby:4.0",
                  command: ["ruby"],
                  args: ["/artifact/app.rb"],
                  ports: [{ name: "http", containerPort: 8080 }],
                  volumeMounts: [
                    { name: "artifact-data", mountPath: "/artifact", readOnly: true },
                  ],
                )
              ]

              spec.template.spec.volumes = [
                { name: "artifact-data", emptyDir: {} },
                { name: "docker-config", secret: {
                  secretName: "oci-registry-creds",
                  items: [{ key: ".dockerconfigjson", path: "config.json" }],
                }},
              ]
            },
          )
        end
      end
    end
  end
end
