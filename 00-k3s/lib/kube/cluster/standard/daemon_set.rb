# frozen_string_literal: true

require 'kube/cluster'
require 'kube/cluster/standard/env_processing'
require 'kube/cluster/standard/volume_processing'

module Kube
  module Cluster
    module Standard
      class DaemonSet < Kube::Cluster['DaemonSet']
        def initialize(
          name:,
          image:,
          env: {},
          volume_mounts: {},
          command: nil,
          service_account: nil,
          node_selector: nil,
          tolerations: nil,
          host_pid: false,
          &block
        )
          processed_env     = EnvProcessing.process(env)
          processed_volumes = VolumeProcessing.process(volume_mounts)

          super() {
            metadata.name   = name
            metadata.labels = { 'app' => name }

            spec.selector.matchLabels = { 'app' => name }

            spec.template.metadata.labels        = { 'app' => name }
            spec.template.spec.serviceAccountName = service_account || name

            container = {
              name:  name,
              image: image,
              env:   processed_env
            }
            container[:command] = command if command
            container[:volumeMounts] = processed_volumes[:volume_mounts] unless processed_volumes[:volume_mounts].empty?

            spec.template.spec.containers = [container]
            spec.template.spec.volumes = processed_volumes[:volumes] unless processed_volumes[:volumes].empty?
            spec.template.spec.hostPID = true if host_pid
            spec.template.spec.nodeSelector = node_selector if node_selector
            spec.template.spec.tolerations = tolerations if tolerations

            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
