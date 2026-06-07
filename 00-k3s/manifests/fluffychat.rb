# frozen_string_literal: true
#
# FluffyChat web client (split out of the production matrix manifest).
# Served by nginx; its config.json points the client at the local homeserver.

FluffychatConfig = Standard::ConfigMap.new(name: 'fluffychat-config') do
  data['config.json'] = {
    default_homeserver:     'localhost',
    homeserver:             'localhost',
    presetHomeserver:       'localhost',
    enableMatrixNativeOIDC: true
  }.to_json
end

FluffychatManifest = Manifest.new(
  FluffychatConfig,
  Standard::DeploymentWithService.new(
    name: 'fluffychat',
    image: 'ghcr.io/n-at-han-k/fluffychat:latest',
    port: 8080,
    volume_mounts: {
      '/usr/share/nginx/html/config.json' => FluffychatConfig.key('config.json')
    }
  ) do
    probes.url       = { path: '/', port: 'http' }
    probes.liveness  = { 10 => 10 }
    probes.readiness = { 5 => 5 }
  end
)
