require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class ConfigMap < Kube::Cluster['ConfigMap']
        KeyRef = Struct.new(:config_map, :key_name)

        def initialize(name: 'config', **options, &block)
          super(**options) do
            metadata.name = name
            instance_exec(&block) if block
          end
        end

        def config_map_name
          to_h.dig(:metadata, :name)
        end

        def key(key_name)
          KeyRef.new(self, key_name)
        end
      end
    end
  end
end
