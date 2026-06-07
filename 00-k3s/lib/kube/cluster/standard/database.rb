# frozen_string_literal: true

require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class Database < Kube::Cluster['Database']
        def initialize(name:, cluster: 'postgres', owner: 'app', &block)
          super() {
            metadata.name              = name
            metadata.namespace         = 'cloudnative-pg'
            spec.cluster               = { name: cluster }
            spec.databaseReclaimPolicy = 'retain'
            spec.ensure                = 'present'
            spec.name                  = name
            spec.owner                 = owner
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
