# frozen_string_literal: true
#
# Local k3s manifest set: Matrix (Synapse + MAS), Ollama, and FluffyChat.
# Rendered to YAML on stdout (the Middleware::Stack `run` below prints it) and piped
# into `kubectl apply` by the applier container. Requires common.rb to be loaded first
# (it sets up bundler + the lib/ load path).

require 'kube/cluster/standard/persistent_volume_claim'
require 'kube/cluster/standard/deployment'
require 'kube/cluster/standard/deployment_with_service'
require 'kube/cluster/standard/config_map'
require 'kube/cluster/standard/secret'
require 'kube/cluster/standard/external_secret'
require 'kube/cluster/standard/service'
require 'kube/cluster/middleware/set_namespace'
require 'kube/cluster/middleware/set_labels'

include Kube::Cluster

require_relative 'manifests/matrix'
require_relative 'manifests/ollama'
require_relative 'manifests/fluffychat'

AiManifest = Manifest.new(
  MatrixManifest,
  OllamaManifest,
  FluffychatManifest
)

Middleware::Stack.new do
  use Middleware::SetNamespace, 'ai'
  use Middleware::SetLabels

  run AiManifest
end
