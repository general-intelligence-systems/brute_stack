require "kube/cluster/standard/postgres_external_secret"

module Kube
  module Cluster
    module Standard
      class PostgresDatabase < Kube::Cluster::Manifest
        def initialize(name:, cluster: "postgres", owner: "app", &block)
          database = Kube::Cluster["Database"].new {
            metadata.name = name
            spec.cluster = { name: cluster }
            spec.databaseReclaimPolicy = "retain"
            spec.ensure = "present"
            spec.name = name
            spec.owner = owner
          }

          external_secret = PostgresExternalSecret.new(name: name)

          super(database, external_secret)
          instance_exec(&block) if block
        end
      end
    end
  end
end
