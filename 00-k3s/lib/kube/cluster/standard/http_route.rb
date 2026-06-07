require 'kube/cluster'

module Kube
  module Cluster
    module Standard
      class HTTPRoute < Kube::Cluster::Manifest
        AUTH_FILTERS = {
          session: 'forwardauth-authelia',
          basic:   'forwardauth-authelia-basic',
          token:   'forwardauth-token'
        }.freeze

        def initialize(
          name:,
          hostname:,
          service:,
          namespace:,
          port:,
          auth:            nil,
          gateway:         nil,
          section:         nil,
          paths:           nil,
          timeouts:        nil,
          http:            :redirect,
          route_namespace: 'kube-system',
          &block
        )
          gw, https_section, http_section = resolve_gateway(hostname, gateway, section)

          matches = (paths || [{ type: 'PathPrefix', value: '/' }]).map { |p|
            { path: p }
          }

          rule = {
            backendRefs: [{
              group: '', kind: 'Service',
              name: service, namespace: namespace,
              port: port, weight: 1
            }],
            matches: matches
          }

          if auth
            middleware = AUTH_FILTERS.fetch(auth) {
              raise ArgumentError, "unknown auth type: #{auth.inspect} (expected #{AUTH_FILTERS.keys.join(', ')})"
            }
            rule[:filters] = [{
              type:         'ExtensionRef',
              extensionRef: { group: 'traefik.io', kind: 'Middleware', name: middleware }
            }]
          end

          rule[:timeouts] = timeouts if timeouts

          https_route = Kube::Cluster['HTTPRoute'].new {
            metadata.name      = name
            metadata.namespace = route_namespace
            spec.hostnames  = [hostname]
            spec.parentRefs = [{
              group:       'gateway.networking.k8s.io',
              kind:        'Gateway',
              name:        gw,
              namespace:   'kube-system',
              sectionName: https_section
            }]
            spec.rules = [rule]
          }

          resources = [https_route]

          if http && http_section
            http_route = Kube::Cluster['HTTPRoute'].new {
              metadata.name      = "#{name}-http"
              metadata.namespace = route_namespace
              spec.hostnames  = [hostname]
              spec.parentRefs = [{
                group:       'gateway.networking.k8s.io',
                kind:        'Gateway',
                name:        gw,
                namespace:   'kube-system',
                sectionName: http_section
              }]

              if http == :passthrough
                spec.rules = [rule]
              else
                spec.rules = [{
                  filters: [{
                    type:            'RequestRedirect',
                    requestRedirect: { scheme: 'https', statusCode: 301 }
                  }],
                  matches: matches
                }]
              end
            }
            resources << http_route
          end

          super(*resources)
          instance_exec(&block) if block
        end

        private

        def resolve_gateway(hostname, gw_override, section_override)
          if hostname == 'cia.net'
            gw           = gw_override || 'kremlin-apex'
            https_section = section_override || 'apex-cia-net-https'
            http_section  = 'apex-cia-net-http'
          elsif hostname == 'kremlin.email'
            gw           = gw_override || 'kremlin-email-apex'
            https_section = section_override || 'apex-kremlin-email-https'
            http_section  = 'apex-kremlin-email-http'
          elsif hostname.end_with?('.cia.net')
            gw           = gw_override || 'main'
            https_section = section_override || 'cia-net-https'
            http_section  = 'cia-net-http'
          else
            slug          = hostname.tr('.', '-')
            gw           = gw_override || 'main'
            https_section = section_override || "#{slug}-https"
            http_section  = "#{slug}-http"
          end

          [gw, https_section, http_section]
        end
      end
    end
  end
end
