require 'kube/cluster'
require 'kube/cluster/standard/service'
require 'kube/cluster/standard/env_processing'
require 'kube/cluster/standard/volume_processing'

module Kube
  module Cluster
    module Standard
      class DeploymentWithService < Kube::Cluster::Manifest
        def initialize(
          name:,
          image:,
          port:,
          namespace: 'default',
          env: {},
          security_context: nil,
          pod_security_context: nil,
          volume_mounts: {},
          service_port: nil,
          &block
        )
          @_limits = {}
          @_probes = {}

          processed_env     = EnvProcessing.process(env)
          processed_volumes = VolumeProcessing.process(volume_mounts)

          service_ports = Array(service_port || port)

          service = Kube::Cluster::Standard::Service.new(
            name: name,
            namespace: namespace,
            ports: service_ports
          )

          deployment = Kube::Cluster['Deployment'].new do
            metadata.name = name
            metadata.namespace = namespace
            metadata.labels = { 'app' => name }

            spec.replicas = 1
            spec.selector.matchLabels = { 'app' => name }

            spec.template.metadata.labels = { 'app' => name }
            spec.template.spec.securityContext = pod_security_context if pod_security_context

            container = {
              name: name,
              image: image,
              ports: [{ name: 'http', containerPort: port, protocol: 'TCP' }],
              env: processed_env
            }
            container[:securityContext] = security_context if security_context
            container[:volumeMounts] = processed_volumes[:volume_mounts] unless processed_volumes[:volume_mounts].empty?

            spec.template.spec.containers = [container]
            spec.template.spec.volumes = processed_volumes[:volumes] unless processed_volumes[:volumes].empty?
          end

          super(deployment, service)

          instance_exec(&block) if block

          _apply_limits(deployment)
          _apply_probes(deployment)
        end

        def limits
          @_limits
        end

        def probes
          @_probes
        end

        private

        def _apply_limits(deployment)
          return if @_limits.empty?

          container = deployment.to_h[:spec][:template][:spec][:containers][0]
          resources = {}

          @_limits.each do |resource_type, mapping|
            mapping.each do |request, limit|
              resources[:requests] ||= {}
              resources[:requests][resource_type] = request.to_s

              if limit != Float::INFINITY
                resources[:limits] ||= {}
                resources[:limits][resource_type] = limit.to_s
              end
            end
          end

          container[:resources] = resources
          h = deployment.to_h
          h[:spec][:template][:spec][:containers][0] = container
          deployment.rebuild(h)
        end

        def _apply_probes(deployment)
          return if @_probes.empty?
          return unless @_probes[:url]

          container = deployment.to_h[:spec][:template][:spec][:containers][0]
          url = @_probes[:url]

          if @_probes[:liveness]
            delay, period = @_probes[:liveness].first
            container[:livenessProbe] = {
              httpGet: url,
              initialDelaySeconds: delay,
              periodSeconds: period,
              timeoutSeconds: 5
            }
          end

          if @_probes[:readiness]
            delay, period = @_probes[:readiness].first
            container[:readinessProbe] = {
              httpGet: url,
              initialDelaySeconds: delay,
              periodSeconds: period,
              timeoutSeconds: 5
            }
          end

          h = deployment.to_h
          h[:spec][:template][:spec][:containers][0] = container
          deployment.rebuild(h)
        end
      end
    end
  end
end
