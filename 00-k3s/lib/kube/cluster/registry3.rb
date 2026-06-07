module Kube
  module Cluster
    class Registry3 < Kube::Cluster::Manifest
      def initialize(name:)
        super(
          Kube::Cluster["ConfigMap"].new {
            metadata.name = "#{name}-config"
            data["config.yaml"] = <<~CONFIG
              version: 0.1
              log:
                level: info
                formatter: json
              storage:
                filesystem:
                  rootdirectory: /var/lib/registry
                delete:
                  enabled: true
                maintenance:
                  uploadpurging:
                    enabled: true
                    age: 168h
                    interval: 24h
                    dryrun: false
              http:
                addr: :5000
                headers:
                  X-Content-Type-Options: [nosniff]
              health:
                storagedriver:
                  enabled: true
                  interval: 10s
                  threshold: 3
            CONFIG
          },

          Kube::Cluster["PersistentVolumeClaim"].new {
            metadata.name = "#{name}-data"

            spec.accessModes = ["ReadWriteOnce"]
            spec.resources.requests.storage = "50Gi"
          },

          Kube::Cluster['Deployment'].new {
            metadata.name = name
            metadata.labels = {app: name}

            spec.selector.matchLabels = {app: name}
            spec.replicas = 1
            spec.template.metadata.labels = {app: name}
            spec.template.spec.containers = [
              Kube::Cluster::Container.new(
                name: "registry",
                image: "registry:3",
                imagePullPolicy: "IfNotPresent",
                args: ["serve", "/etc/distribution/config.yaml"],
                ports: [{name: "http", containerPort: 5000}],
                volumeMounts: [
                  {name: "config", mountPath: "/etc/distribution"},
                  {name: "data", mountPath: "/var/lib/registry"},
                ],
              )
            ]
            spec.template.spec.volumes = [
              {name: "config", configMap: {name: "#{name}-config"}},
              {name: "data", persistentVolumeClaim: {claimName: "#{name}-data"}}
            ]
          },

          Kube::Cluster["Service"].new {
            metadata.name = name

            spec.selector = {app: name}
            spec.ports = [{name: "http", port: 5000, targetPort: "http"}]
          },
        )
      end
    end
  end
end
