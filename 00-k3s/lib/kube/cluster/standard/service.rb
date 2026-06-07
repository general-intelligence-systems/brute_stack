module Kube
  module Cluster
    module Standard
      class Service < Kube::Cluster["Service"]
        def initialize(name:, ports:, namespace: "default", **options, &block)
          super() {
            metadata.name = name
            metadata.namespace = namespace
            metadata.labels = { "app" => name }
            spec.selector = { "app" => name }
            spec.ports = ports.map do |port|
              { name: "http-#{port}", port: port, targetPort: port, protocol: "TCP" }
            end

            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end
