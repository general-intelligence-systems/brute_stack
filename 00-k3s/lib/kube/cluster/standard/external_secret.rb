module Kube
  module Cluster
    module Standard
      class ExternalSecret < Kube::Cluster['ExternalSecret']
        # Returned by .template — carries the secret ref and template value.
        # When the env hash is processed, the key becomes both the env var name
        # and the secret template data key.
        TemplateRef = Struct.new(:secret, :template_value)

        # Returned by .key — carries the secret ref and key name.
        # When the volume_mounts hash is processed, this tells the volume
        # processing layer to mount a single key from the secret as a file.
        KeyRef = Struct.new(:secret, :key_name)

        attr_reader :secret_name

        def initialize(name:, store:, remote_key:, keys: nil, deletion_policy: nil, &block)
          @secret_name = name
          @remote_key = remote_key
          @_template_data = {}
          @_remote_properties = {}
          @_keys = keys
          @_deletion_policy = deletion_policy

          super() do
            metadata.name = name
            spec.refreshInterval = '1h'
            spec.secretStoreRef = { kind: 'ClusterSecretStore', name: store }

            target = { name: name, creationPolicy: 'Owner' }
            target[:deletionPolicy] = deletion_policy if deletion_policy
            spec.target = target

            if keys
              spec.data = keys.map do |secret_key, property|
                { secretKey: secret_key, remoteRef: { key: remote_key, property: property } }
              end
            end

            instance_exec(&block) if block
          end
        end

        # Returns a TemplateRef. The env hash processor calls .register!
        # on the ref to wire up the template data and remote properties.
        def template(template_string)
          TemplateRef.new(self, template_string)
        end
        alias with_template template

        # Returns a KeyRef for mounting a single key from this secret as a file.
        # The volume processing layer uses this to generate the volume and mount.
        def key(key_name)
          KeyRef.new(self, key_name)
        end

        # Called by env processing to register a template entry.
        def register_template!(env_key, template_string)
          @_template_data[env_key] = template_string

          template_string.scan(/\{\{\s*\.(\w+)\s*\}\}/) do |match|
            @_remote_properties[match[0]] = true
          end

          @data.spec.target.template = { data: @_template_data }
          @data.spec.data = @_remote_properties.keys.map do |prop|
            { secretKey: prop, remoteRef: { key: @remote_key, property: prop } }
          end
        end
      end
    end
  end
end
