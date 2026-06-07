module Kube
  module Cluster
    module Standard
      class Secret < Kube::Cluster["Secret"]
        def initialize(name:, **data, &block)
          super() {
            metadata.name = name
            data.each { |k, v| stringData[k.to_s] = v }
            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end
