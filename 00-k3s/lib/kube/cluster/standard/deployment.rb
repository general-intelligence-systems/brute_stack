require 'kube/cluster'
require 'kube/cluster/standard/env_processing'
require 'kube/cluster/standard/volume_processing'

module Kube
  module Cluster
    module Standard
      class Deployment < Kube::Cluster['Deployment']
        def initialize(
          name:,
          image:,
          env: {},
          volume_mounts: {},
          command: nil,
          service_account: nil,
          termination_grace_period: nil,
          &block
        )
          @_limits = {}

          processed_env     = EnvProcessing.process(env)
          processed_volumes = VolumeProcessing.process(volume_mounts)

          super() {
            metadata.name   = name
            metadata.labels = { 'app' => name }

            spec.replicas             = 1
            spec.selector.matchLabels = { 'app' => name }

            spec.template.metadata.labels        = { 'app' => name }
            spec.template.spec.serviceAccountName = service_account || name

            if termination_grace_period
              spec.template.spec.terminationGracePeriodSeconds = termination_grace_period
            end

            container = {
              name:  name,
              image: image,
              env:   processed_env
            }
            container[:command] = command if command
            container[:volumeMounts] = processed_volumes[:volume_mounts] unless processed_volumes[:volume_mounts].empty?

            spec.template.spec.containers = [container]
            spec.template.spec.volumes = processed_volumes[:volumes] unless processed_volumes[:volumes].empty?

            instance_exec(&block) if block
          }

          _apply_limits
        end

        def limits
          @_limits
        end

        private

          def _apply_limits
            return if @_limits.empty?

            container = to_h[:spec][:template][:spec][:containers][0]
            resources = {}

            @_limits.each { |resource_type, mapping|
              mapping.each { |request, limit|
                resources[:requests] ||= {}
                resources[:requests][resource_type] = request.to_s

                if limit != Float::INFINITY
                  resources[:limits] ||= {}
                  resources[:limits][resource_type] = limit.to_s
                end
              }
            }

            container[:resources] = resources
            h = to_h
            h[:spec][:template][:spec][:containers][0] = container
            rebuild(h)
          end
      end
    end
  end
end
