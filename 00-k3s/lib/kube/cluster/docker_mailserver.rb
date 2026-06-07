# frozen_string_literal: true

module Kube
  module Cluster
    class DockerMailserver < Kube::Cluster::Manifest
      IMAGE    = "ghcr.io/docker-mailserver/docker-mailserver:latest"
      HOSTNAME = "mail.kremlin.email"

      def initialize(
        name: "mailserver",
        image: IMAGE,
        hostname: HOSTNAME,
        storage_size: "25Gi",
        storage_class: "local-path",
        tls_secret_name: "mail-tls-certificate-rsa",
        tls_issuer_name: "letsencrypt-production",
        tls_issuer_kind: "ClusterIssuer",
        **options
      )
        labels = {
          "app.kubernetes.io/name"     => name,
          "app.kubernetes.io/instance" => name,
        }

        # -- ConfigMap: environment variables ----------------------------------
        env_config = Kube::Cluster["ConfigMap"].new {
          metadata.name = "#{name}-environment"
          data.merge!(
            "OVERRIDE_HOSTNAME"      => hostname,
            "TLS_LEVEL"              => "modern",
            "SSL_TYPE"               => "manual",
            "SSL_CERT_PATH"          => "/secrets/ssl/rsa/tls.crt",
            "SSL_KEY_PATH"           => "/secrets/ssl/rsa/tls.key",
            "POSTMASTER_ADDRESS"     => "postmaster@#{hostname.sub(/^mail\./, '')}",
            "POSTSCREEN_ACTION"      => "drop",
            "FAIL2BAN_BLOCKTYPE"     => "drop",
            "UPDATE_CHECK_INTERVAL"  => "10d",
            "POSTFIX_INET_PROTOCOLS" => "ipv4",
            "ENABLE_CLAMAV"          => "1",
            "ENABLE_FAIL2BAN"        => "1",
            "ENABLE_POSTGREY"        => "0",
            "ENABLE_SPAMASSASSIN"    => "1",
            "SPOOF_PROTECTION"       => "1",
            "MOVE_SPAM_TO_JUNK"      => "1",
            "ENABLE_UPDATE_CHECK"    => "1",
            "SUPERVISOR_LOGLEVEL"    => "warn",
            "SPAMASSASSIN_SPAM_TO_INBOX" => "1",
            "AMAVIS_LOGLEVEL"        => "-1",
          )
        }

        # -- PersistentVolumeClaim: mail data ----------------------------------
        pvc = Kube::Cluster["PersistentVolumeClaim"].new {
          metadata.name = "#{name}-data"
          spec.storageClassName = storage_class
          spec.accessModes = ["ReadWriteOnce"]
          spec.resources = { requests: { storage: storage_size } }
        }

        # -- Certificate: TLS via cert-manager ---------------------------------
        certificate = Kube::Cluster["Certificate"].new {
          metadata.name = "#{name}-tls-rsa"
          spec.secretName = tls_secret_name
          spec.issuerRef = { name: tls_issuer_name, kind: tls_issuer_kind }
          spec.privateKey = { algorithm: "RSA", encoding: "PKCS1", size: 2048 }
          spec.dnsNames = [hostname]
        }

        # -- Deployment: hostNetwork -------------------------------------------
        deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = labels
          metadata.annotations = {
            "ignore-check.kube-linter.io/run-as-non-root"         => "mailserver needs to run as root",
            "ignore-check.kube-linter.io/privileged-ports"        => "mailserver needs privileged ports",
            "ignore-check.kube-linter.io/no-read-only-root-fs"    => "too many files written to make root FS read-only",
          }

          spec.replicas = 1
          spec.selector.matchLabels = labels

          spec.template.metadata.labels = labels
          spec.template.spec.hostNetwork = true
          spec.template.spec.hostname = "mail"
          spec.template.spec.restartPolicy = "Always"

          spec.template.spec.containers = [
            {
              name: name,
              image: image,
              imagePullPolicy: "IfNotPresent",
              securityContext: {
                allowPrivilegeEscalation: true,
                readOnlyRootFilesystem: false,
                runAsUser: 0,
                runAsGroup: 0,
                runAsNonRoot: false,
                privileged: false,
                capabilities: {
                  add: %w[
                    CHOWN FOWNER MKNOD SETGID SETUID DAC_OVERRIDE
                    NET_ADMIN NET_RAW NET_BIND_SERVICE
                    SYS_CHROOT KILL
                  ],
                  drop: ["ALL"],
                },
                seccompProfile: { type: "RuntimeDefault" },
              },
              resources: {
                requests: { cpu: "600m",  memory: "2Gi" },
                limits:   { cpu: "1500m", memory: "4Gi" },
              },
              ports: [
                { name: "smtp",        containerPort: 25,  hostPort: 25,  protocol: "TCP" },
                { name: "submissions", containerPort: 465, hostPort: 465, protocol: "TCP" },
                { name: "submission",  containerPort: 587, hostPort: 587, protocol: "TCP" },
                { name: "imaps",       containerPort: 993, hostPort: 993, protocol: "TCP" },
              ],
              volumeMounts: [
                { name: "data", mountPath: "/var/mail",       subPath: "data",  readOnly: false },
                { name: "data", mountPath: "/var/mail-state", subPath: "state", readOnly: false },
                { name: "data", mountPath: "/var/log/mail",   subPath: "log",   readOnly: false },
                { name: "certificates-rsa", mountPath: "/secrets/ssl/rsa/", readOnly: true },
              ],
              envFrom: [{ configMapRef: { name: "#{name}-environment" } }],
            },
          ]

          spec.template.spec.volumes = [
            { name: "data", persistentVolumeClaim: { claimName: "#{name}-data" } },
            {
              name: "certificates-rsa",
              secret: {
                secretName: tls_secret_name,
                items: [
                  { key: "tls.key", path: "tls.key" },
                  { key: "tls.crt", path: "tls.crt" },
                ],
              },
            },
          ]
        }

        # -- Service: ClusterIP (for in-cluster access) ------------------------
        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = labels
          spec.selector = labels
          spec.ports = [
            { name: "smtp",        port: 25,  targetPort: "smtp",        protocol: "TCP" },
            { name: "submissions", port: 465, targetPort: "submissions", protocol: "TCP" },
            { name: "submission",  port: 587, targetPort: "submission",  protocol: "TCP" },
            { name: "imaps",       port: 993, targetPort: "imaps",       protocol: "TCP" },
          ]
        }

        super(env_config, pvc, certificate, deployment, service)
      end
    end
  end
end
