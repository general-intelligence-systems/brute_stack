# frozen_string_literal: true

module Kube
  module Cluster
    class KremlinGateway < Kube::Cluster::Manifest
      def initialize(&block)
        gateway = Kube::Cluster["Gateway"].new {
          metadata.name = "kremlin"
          metadata.namespace = "kube-system"
          spec.gatewayClassName = "traefik"
          spec.listeners = [
            {
              name: "webdav-kremlin-email-https",
              hostname: "webdav.kremlin.email",
              port: 8443,
              protocol: "HTTPS",
              tls: {
                mode: "Terminate",
                certificateRefs: [{ group: "", kind: "Secret", name: "wildcard-kremlin-email-tls" }],
              },
              allowedRoutes: { namespaces: { from: "All" } },
            },
            {
              name: "webdav-kremlin-email-http",
              hostname: "webdav.kremlin.email",
              port: 8000,
              protocol: "HTTP",
              allowedRoutes: { namespaces: { from: "All" } },
            },
            {
              name: "caldav-kremlin-email-https",
              hostname: "caldav.kremlin.email",
              port: 8443,
              protocol: "HTTPS",
              tls: {
                mode: "Terminate",
                certificateRefs: [{ group: "", kind: "Secret", name: "wildcard-kremlin-email-tls" }],
              },
              allowedRoutes: { namespaces: { from: "All" } },
            },
            {
              name: "caldav-kremlin-email-http",
              hostname: "caldav.kremlin.email",
              port: 8000,
              protocol: "HTTP",
              allowedRoutes: { namespaces: { from: "All" } },
            },
          ]
        }

        httproute = Kube::Cluster["HTTPRoute"].new {
          metadata.name = "webdav"
          metadata.namespace = "kube-system"
          spec.hostnames = ["webdav.kremlin.email"]
          spec.parentRefs = [
            {
              group: "gateway.networking.k8s.io",
              kind: "Gateway",
              name: "kremlin",
              namespace: "kube-system",
              sectionName: "webdav-kremlin-email-https",
            },
          ]
          spec.rules = [
            {
              matches: [{ path: { type: "PathPrefix", value: "/" } }],
              backendRefs: [
                {
                  group: "",
                  kind: "Service",
                  name: "webdav",
                  namespace: "default",
                  port: 80,
                  weight: 1,
                },
              ],
            },
          ]
        }

        caldav_httproute = Kube::Cluster["HTTPRoute"].new {
          metadata.name = "caldav"
          metadata.namespace = "kube-system"
          spec.hostnames = ["caldav.kremlin.email"]
          spec.parentRefs = [
            {
              group: "gateway.networking.k8s.io",
              kind: "Gateway",
              name: "kremlin",
              namespace: "kube-system",
              sectionName: "caldav-kremlin-email-https",
            },
          ]
          spec.rules = [
            {
              matches: [{ path: { type: "PathPrefix", value: "/" } }],
              filters: [
                {
                  extensionRef: {
                    group: "traefik.io",
                    kind: "Middleware",
                    name: "forwardauth-authelia-basic",
                  },
                  type: "ExtensionRef",
                },
              ],
              backendRefs: [
                {
                  group: "",
                  kind: "Service",
                  name: "caldav",
                  namespace: "default",
                  port: 9292,
                  weight: 1,
                },
              ],
            },
          ]
        }

        super(gateway, httproute, caldav_httproute)
        instance_exec(&block) if block
      end
    end
  end
end
