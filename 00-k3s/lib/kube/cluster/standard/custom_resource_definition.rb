require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class CustomResourceDefinition < Kube::Cluster['CustomResourceDefinition']
        def initialize(kind:, group:, version: 'v1', scope: 'Namespaced',
                       short_names: [], categories: [], schema: nil, &block)
          plural   = kind.downcase.pluralize
          singular = kind.downcase

          schema ||= {
            type: 'object',
            'x-kubernetes-preserve-unknown-fields': true
          }

          super() {
            metadata.name = "#{plural}.#{group}"

            spec.group          = group
            spec.names.kind     = kind
            spec.names.listKind = "#{kind}List"
            spec.names.plural   = plural
            spec.names.singular = singular
            spec.names.shortNames = short_names unless short_names.empty?
            spec.names.categories = categories  unless categories.empty?
            spec.scope          = scope
            spec.versions = [{
              name:         version,
              served:       true,
              storage:      true,
              subresources: { status: {} },
              schema: {
                openAPIV3Schema: schema
              }
            }]

            instance_exec(&block) if block
          }

          api_version = "#{group}/#{version}"
          Kube::Schema.register(
            kind,
            schema:      {
              'type' => 'object',
              'properties' => {
                'apiVersion' => { 'type' => 'string' },
                'kind'       => { 'type' => 'string' },
                'metadata'   => { 'type' => 'object' },
                'spec'       => { 'type' => 'object', 'x-kubernetes-preserve-unknown-fields' => true },
                'status'     => { 'type' => 'object', 'x-kubernetes-preserve-unknown-fields' => true }
              },
              'x-kubernetes-preserve-unknown-fields' => true
            },
            api_version: api_version
          )
        end
      end
    end
  end
end
