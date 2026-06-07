# frozen_string_literal: true

module Kube
  module Cluster
    module Standard
      module VolumeProcessing
        # Convert a volume_mounts hash into Kubernetes volumes and volumeMounts arrays.
        #
        # Hash values (mount path => source ref):
        #   ExternalSecret::KeyRef  => secret volume with items, mount with subPath + readOnly
        #   ExternalSecret          => secret volume, directory mount
        #   PersistentVolumeClaim   => persistentVolumeClaim volume, plain mount
        #
        # Legacy: if input is an Array, it is returned as-is for backwards compat.
        #
        def self.process(input)
          return { volumes: [], volume_mounts: input } if input.is_a?(Array)
          return { volumes: [], volume_mounts: [] } if input.nil? || input.empty?

          volumes = []
          mounts = []

          input.each do |mount_path, source|
            case source
            when ExternalSecret::KeyRef
              name = source.secret.secret_name
              key  = source.key_name
              volumes << {
                name: name,
                secret: {
                  secretName: name,
                  items: [{ key: key, path: key }]
                }
              }
              mounts << {
                name: name,
                mountPath: mount_path,
                subPath: key,
                readOnly: true
              }

            when ExternalSecret
              name = source.secret_name
              volumes << { name: name, secret: { secretName: name } }
              mounts  << { name: name, mountPath: mount_path }

            when PersistentVolumeClaim
              name = source.to_h.dig(:metadata, :name)
              volumes << { name: name, persistentVolumeClaim: { claimName: name } }
              mounts  << { name: name, mountPath: mount_path }

            when ConfigMap::KeyRef
              name = source.config_map.config_map_name
              key  = source.key_name
              volumes << {
                name: name,
                configMap: {
                  name: name,
                  items: [{ key: key, path: key }]
                }
              }
              mounts << {
                name: name,
                mountPath: mount_path,
                subPath: key,
                readOnly: true
              }

            when ConfigMap
              name = source.to_h.dig(:metadata, :name)
              volumes << { name: name, configMap: { name: name } }
              mounts  << { name: name, mountPath: mount_path, readOnly: true }
            end
          end

          { volumes: volumes, volume_mounts: mounts }
        end
      end
    end
  end
end
