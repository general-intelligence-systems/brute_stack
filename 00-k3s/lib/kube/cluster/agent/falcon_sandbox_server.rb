module Kube
  module Cluster
    module Agent
      class FalconSandboxServer < Kube::Cluster::Manifest
        #def initialize(
        #  name: "falcon-agent-server",
        #  image: "registry.cia.net/falcon-agent-server:latest",
        #  sandbox_template: "sandbox-template",
        #  **options
        #)

        #  sa = Kube::Cluster["ServiceAccount"].new {
        #    metadata.name = name
        #  }

        #  role = Kube::Cluster["Role"].new {
        #    metadata.name = name
        #    self.rules = [
        #      {
        #        apiGroups: ["extensions.agents.x-k8s.io"],
        #        resources: ["sandboxclaims"],
        #        verbs: ["create", "get", "list", "watch", "delete"],
        #      },
        #      {
        #        apiGroups: ["agents.x-k8s.io"],
        #        resources: ["sandboxes"],
        #        verbs: ["get", "list"],
        #      },
        #    ]
        #  }

        #  role_binding = Kube::Cluster["RoleBinding"].new {
        #    metadata.name = name
        #    roleRef.apiGroup = "rbac.authorization.k8s.io"
        #    roleRef.kind = "Role"
        #    roleRef.name = name
        #    self.subjects = [{ kind: "ServiceAccount", name: name }]
        #  }

        #  super(sa, role, role_binding, deployment, service)
        #end
      end
    end
  end
end
