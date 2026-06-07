# frozen_string_literal: true

module Kube
  module Cluster
    class CsiS3 < Kube::Cluster::Manifest
      CSI_S3_IMAGE = "cr.yandex/crp9ftr22d26age3hulg/csi-s3:0.43.7"

      def initialize(name: "csi-s3", namespace: "kube-system", &block)
        # -- ExternalSecret for S3 credentials (sourced from secret-store namespace) --
        external_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "csi-s3-secret"
          metadata.namespace = namespace
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: "kubernetes" }
          spec.target = {
            name: "csi-s3-secret",
            creationPolicy: "Owner",
            deletionPolicy: "Retain",
          }
          spec.data = [
            { secretKey: "accessKeyID", remoteRef: { key: "cloudflare-apache-webdav", property: "accessKeyID" } },
            { secretKey: "secretAccessKey", remoteRef: { key: "cloudflare-apache-webdav", property: "secretAccessKey" } },
            { secretKey: "endpoint", remoteRef: { key: "cloudflare-apache-webdav", property: "endpoint" } },
          ]
        }

        # -- CSIDriver --
        csi_driver = Kube::Cluster["CSIDriver"].new {
          metadata.name = "ru.yandex.s3.csi"
          spec.attachRequired = false
          spec.podInfoOnMount = true
        }

        # -- StorageClass --
        storage_class = Kube::Cluster["StorageClass"].new {
          metadata.name = "csi-s3"
          self.provisioner = "ru.yandex.s3.csi"
          self.parameters = {
            "mounter" => "geesefs",
            "options" => "--memory-limit 1000 --dir-mode 0777 --file-mode 0666",
            "csi.storage.k8s.io/provisioner-secret-name" => "csi-s3-secret",
            "csi.storage.k8s.io/provisioner-secret-namespace" => namespace,
            "csi.storage.k8s.io/controller-publish-secret-name" => "csi-s3-secret",
            "csi.storage.k8s.io/controller-publish-secret-namespace" => namespace,
            "csi.storage.k8s.io/node-stage-secret-name" => "csi-s3-secret",
            "csi.storage.k8s.io/node-stage-secret-namespace" => namespace,
            "csi.storage.k8s.io/node-publish-secret-name" => "csi-s3-secret",
            "csi.storage.k8s.io/node-publish-secret-namespace" => namespace,
          }
        }

        # -- Node Plugin ServiceAccount + RBAC --
        node_sa = Kube::Cluster["ServiceAccount"].new {
          metadata.name = "csi-s3"
          metadata.namespace = namespace
        }

        node_role = Kube::Cluster["ClusterRole"].new {
          metadata.name = "csi-s3"
        }

        node_role_binding = Kube::Cluster["ClusterRoleBinding"].new {
          metadata.name = "csi-s3"
          self.subjects = [
            { kind: "ServiceAccount", name: "csi-s3", namespace: namespace },
          ]
          self.roleRef = {
            kind: "ClusterRole",
            name: "csi-s3",
            apiGroup: "rbac.authorization.k8s.io",
          }
        }

        # -- Node Plugin DaemonSet --
        daemonset = Kube::Cluster["DaemonSet"].new {
          metadata.name = "csi-s3"
          metadata.namespace = namespace
          spec.selector.matchLabels = { "app" => "csi-s3" }
          spec.template.metadata.labels = { "app" => "csi-s3" }
          spec.template.spec.serviceAccount = "csi-s3"
          spec.template.spec.tolerations = [
            { key: "CriticalAddonsOnly", operator: "Exists" },
            { operator: "Exists", effect: "NoExecute", tolerationSeconds: 300 },
          ]
          spec.template.spec.containers = [
            {
              name: "driver-registrar",
              image: "cr.yandex/crp9ftr22d26age3hulg/yandex-cloud/csi-s3/csi-node-driver-registrar:v2.16.0",
              args: [
                "--kubelet-registration-path=$(DRIVER_REG_SOCK_PATH)",
                "--v=4",
                "--csi-address=$(ADDRESS)",
              ],
              env: [
                { name: "ADDRESS", value: "/csi/csi.sock" },
                { name: "DRIVER_REG_SOCK_PATH", value: "/var/lib/kubelet/plugins/ru.yandex.s3.csi/csi.sock" },
                { name: "KUBE_NODE_NAME", valueFrom: { fieldRef: { fieldPath: "spec.nodeName" } } },
              ],
              volumeMounts: [
                { name: "plugin-dir", mountPath: "/csi" },
                { name: "registration-dir", mountPath: "/registration/" },
              ],
            },
            {
              name: "csi-s3",
              securityContext: {
                privileged: true,
                capabilities: { add: ["SYS_ADMIN"] },
                allowPrivilegeEscalation: true,
              },
              image: CSI_S3_IMAGE,
              imagePullPolicy: "IfNotPresent",
              args: [
                "--endpoint=$(CSI_ENDPOINT)",
                "--nodeid=$(NODE_ID)",
                "--v=4",
              ],
              env: [
                { name: "CSI_ENDPOINT", value: "unix:///csi/csi.sock" },
                { name: "NODE_ID", valueFrom: { fieldRef: { fieldPath: "spec.nodeName" } } },
              ],
              volumeMounts: [
                { name: "plugin-dir", mountPath: "/csi" },
                { name: "stage-dir", mountPath: "/var/lib/kubelet/plugins/kubernetes.io/csi", mountPropagation: "Bidirectional" },
                { name: "pods-mount-dir", mountPath: "/var/lib/kubelet/pods", mountPropagation: "Bidirectional" },
                { name: "fuse-device", mountPath: "/dev/fuse" },
                { name: "systemd-control", mountPath: "/run/systemd" },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "registration-dir", hostPath: { path: "/var/lib/kubelet/plugins_registry/", type: "DirectoryOrCreate" } },
            { name: "plugin-dir", hostPath: { path: "/var/lib/kubelet/plugins/ru.yandex.s3.csi", type: "DirectoryOrCreate" } },
            { name: "stage-dir", hostPath: { path: "/var/lib/kubelet/plugins/kubernetes.io/csi", type: "DirectoryOrCreate" } },
            { name: "pods-mount-dir", hostPath: { path: "/var/lib/kubelet/pods", type: "Directory" } },
            { name: "fuse-device", hostPath: { path: "/dev/fuse" } },
            { name: "systemd-control", hostPath: { path: "/run/systemd", type: "DirectoryOrCreate" } },
          ]
        }

        # -- Provisioner ServiceAccount + RBAC --
        provisioner_sa = Kube::Cluster["ServiceAccount"].new {
          metadata.name = "csi-s3-provisioner-sa"
          metadata.namespace = namespace
        }

        provisioner_role = Kube::Cluster["ClusterRole"].new {
          metadata.name = "csi-s3-external-provisioner-runner"
          self.rules = [
            { apiGroups: [""], resources: ["secrets"], verbs: ["get", "list"] },
            { apiGroups: [""], resources: ["persistentvolumes"], verbs: ["get", "list", "watch", "create", "patch", "delete"] },
            { apiGroups: [""], resources: ["persistentvolumeclaims"], verbs: ["get", "list", "watch", "update"] },
            { apiGroups: ["storage.k8s.io"], resources: ["storageclasses"], verbs: ["get", "list", "watch"] },
            { apiGroups: [""], resources: ["events"], verbs: ["list", "watch", "create", "update", "patch"] },
          ]
        }

        provisioner_role_binding = Kube::Cluster["ClusterRoleBinding"].new {
          metadata.name = "csi-s3-provisioner-role"
          self.subjects = [
            { kind: "ServiceAccount", name: "csi-s3-provisioner-sa", namespace: namespace },
          ]
          self.roleRef = {
            kind: "ClusterRole",
            name: "csi-s3-external-provisioner-runner",
            apiGroup: "rbac.authorization.k8s.io",
          }
        }

        # -- Provisioner Service --
        provisioner_service = Kube::Cluster["Service"].new {
          metadata.name = "csi-s3-provisioner"
          metadata.namespace = namespace
          metadata.labels = { "app" => "csi-s3-provisioner" }
          spec.selector = { "app" => "csi-s3-provisioner" }
          spec.ports = [{ name: "csi-s3-dummy", port: 65535 }]
        }

        # -- Provisioner StatefulSet --
        provisioner = Kube::Cluster["StatefulSet"].new {
          metadata.name = "csi-s3-provisioner"
          metadata.namespace = namespace
          spec.serviceName = "csi-provisioner-s3"
          spec.replicas = 1
          spec.selector.matchLabels = { "app" => "csi-s3-provisioner" }
          spec.template.metadata.labels = { "app" => "csi-s3-provisioner" }
          spec.template.spec.serviceAccount = "csi-s3-provisioner-sa"
          spec.template.spec.tolerations = [
            { key: "node-role.kubernetes.io/master", operator: "Exists" },
            { key: "CriticalAddonsOnly", operator: "Exists" },
          ]
          spec.template.spec.containers = [
            {
              name: "csi-provisioner",
              image: "cr.yandex/crp9ftr22d26age3hulg/yandex-cloud/csi-s3/csi-provisioner:v6.2.0",
              args: [
                "--csi-address=$(ADDRESS)",
                "--v=4",
              ],
              env: [
                { name: "ADDRESS", value: "/var/lib/kubelet/plugins/ru.yandex.s3.csi/csi.sock" },
              ],
              imagePullPolicy: "IfNotPresent",
              volumeMounts: [
                { name: "socket-dir", mountPath: "/var/lib/kubelet/plugins/ru.yandex.s3.csi" },
              ],
            },
            {
              name: "csi-s3",
              image: CSI_S3_IMAGE,
              imagePullPolicy: "IfNotPresent",
              args: [
                "--endpoint=$(CSI_ENDPOINT)",
                "--nodeid=$(NODE_ID)",
                "--v=4",
              ],
              env: [
                { name: "CSI_ENDPOINT", value: "unix:///var/lib/kubelet/plugins/ru.yandex.s3.csi/csi.sock" },
                { name: "NODE_ID", valueFrom: { fieldRef: { fieldPath: "spec.nodeName" } } },
              ],
              volumeMounts: [
                { name: "socket-dir", mountPath: "/var/lib/kubelet/plugins/ru.yandex.s3.csi" },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "socket-dir", emptyDir: {} },
          ]
        }

        super(
          external_secret,
          csi_driver,
          storage_class,
          node_sa,
          node_role,
          node_role_binding,
          daemonset,
          provisioner_sa,
          provisioner_role,
          provisioner_role_binding,
          provisioner_service,
          provisioner,
        )

        instance_exec(&block) if block
      end
    end
  end
end
