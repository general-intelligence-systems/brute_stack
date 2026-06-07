# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class Perses < Kube::Cluster['Perses']
        def initialize(name:, image:, port: 8080, &block)
          super() {
            metadata.name      = name
            spec.image         = image
            spec.containerPort = port
            spec.config = {
              database: {
                file: {
                  folder:    '/perses',
                  extension: 'json',
                },
              },
            }
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
