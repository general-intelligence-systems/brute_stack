# frozen_string_literal: true

require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Sets +app.kubernetes.io/name+ and +app.kubernetes.io/instance+
      # from +metadata.name+ on every resource that has a name.
      #
      #   use SetLabels
      #
      class SetLabels < Middleware
        def call(manifest)
          manifest.resources.map! { |resource|
            h = resource.to_h
            name = h.dig(:metadata, :name)
            next resource unless name

            h[:metadata][:labels] ||= {}
            h[:metadata][:labels][:'app.kubernetes.io/name'] ||= name
            h[:metadata][:labels][:'app.kubernetes.io/instance'] ||= name
            resource.rebuild(h)
          }
        end
      end
    end
  end
end
