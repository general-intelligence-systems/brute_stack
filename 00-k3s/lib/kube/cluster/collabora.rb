# frozen_string_literal: true

module Kube
  module Cluster
    class Collabora < Kube::Cluster::Manifest
      BRANDING_CSS_URL = "https://gist.githubusercontent.com/mickael-kerjean/bc1f57cd312cf04731d30185cc4e7ba2/raw/d706dcdf23c21441e5af289d871b33defc2770ea/destop.css"

      def initialize(name: "office", image: "collabora/code:24.04.10.2.1", **options)
        deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = { "app" => name }

          spec.replicas = 1
          spec.selector.matchLabels = { "app" => name }

          spec.template.metadata.labels = { "app" => name }
          spec.template.spec.securityContext = { runAsUser: 0 }
          spec.template.spec.initContainers = [
            {
              name: "fetch-branding",
              image: "curlimages/curl:latest",
              command: [
                "sh", "-c",
                "curl -fSsLo /branding/branding-desktop.css #{BRANDING_CSS_URL}",
              ],
              volumeMounts: [{ name: "branding", mountPath: "/branding" }],
            },
          ]
          spec.template.spec.containers = [
            {
              name: "collabora",
              image: image,
              imagePullPolicy: "IfNotPresent",
              ports: [{ containerPort: 9980, protocol: "TCP" }],
              env: [
                { name: "extra_params", value: "--o:ssl.enable=false" },
                { name: "aliasgroup1",  value: "https://.*:443" },
              ],
              volumeMounts: [
                {
                  name: "branding",
                  mountPath: "/usr/share/coolwsd/browser/dist/branding-desktop.css",
                  subPath: "branding-desktop.css",
                },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "branding", emptyDir: {} },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.ports = [{ port: 9980, targetPort: 9980, protocol: "TCP" }]
        }

        super(deployment, service)
      end
    end
  end
end
