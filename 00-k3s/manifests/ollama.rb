# frozen_string_literal: true
#
# Ollama (split out of the production agents manifest). The agentgateway proxy/route
# resources from production are dropped — bare k3s has no agentgateway CRDs, and agents
# reach Ollama directly via its in-cluster Service (ollama.ai.svc.cluster.local:11434).
#
# Pulls qwen2.5:0.5b at startup (the lightweight teaching default) instead of llama3.2.

module PVC
  OllamaData = Standard::PersistentVolumeClaim.new(
    name: 'ollama-data',
    storage: '20Gi',
    storage_class: 'local-path'
  )
end

OllamaManifest = Manifest.new(
  PVC::OllamaData,
  Standard::Deployment.new(
    name: 'ollama',
    image: 'ollama/ollama',
    service_account: 'default',
    volume_mounts: {
      '/root/.ollama' => PVC::OllamaData
    }
  ) do
    spec.template.spec.initContainers = [{
      name: 'pull-models',
      image: 'ollama/ollama',
      command: ShScript(<<~'SH'),
        ollama serve &
        until ollama list >/dev/null 2>&1; do sleep 1; done
        ollama pull qwen2.5:0.5b
        kill $! || true
      SH
      volumeMounts: [{
        name: 'ollama-data',
        mountPath: '/root/.ollama'
      }]
    }]
  end,
  Standard::Service.new(
    name: 'ollama',
    ports: [11_434]
  )
)
