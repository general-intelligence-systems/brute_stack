module Kube
  module Cluster
    module Standard
      class PersistentVolumeClaim < Kube::Cluster["PersistentVolumeClaim"]
        def initialize(name:, storage:, access_modes: ["ReadWriteOnce"], storage_class: nil, &block)
          super() {
            metadata.name = name
            spec.accessModes = access_modes
            spec.storageClassName = storage_class if storage_class
            spec.resources = { requests: { storage: storage } }
            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end
