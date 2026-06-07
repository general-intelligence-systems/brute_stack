# frozen_string_literal: true

module Kube
  module Cluster
    class ApacheWebDavServer < Kube::Cluster::Manifest
      HTTPD_CONF = <<~CONF
        ServerRoot "/usr/local/apache2"

        LoadModule mpm_event_module modules/mod_mpm_event.so
        LoadModule alias_module modules/mod_alias.so
        LoadModule authn_core_module modules/mod_authn_core.so
        LoadModule authz_core_module modules/mod_authz_core.so
        LoadModule authz_user_module modules/mod_authz_user.so
        LoadModule authnz_ldap_module modules/mod_authnz_ldap.so
        LoadModule ldap_module modules/mod_ldap.so
        LoadModule dav_module modules/mod_dav.so
        LoadModule dav_fs_module modules/mod_dav_fs.so
        LoadModule unixd_module modules/mod_unixd.so
        LoadModule log_config_module modules/mod_log_config.so
        LoadModule mime_module modules/mod_mime.so
        LoadModule autoindex_module modules/mod_autoindex.so
        LoadModule auth_basic_module modules/mod_auth_basic.so
        LoadModule headers_module modules/mod_headers.so
        LoadModule setenvif_module modules/mod_setenvif.so

        Listen 80
        User www-data
        Group www-data

        ErrorLog /proc/self/fd/2
        LogFormat "%%h %%l %%u %%t \\"%%r\\" %%>s %%b" common
        CustomLog /proc/self/fd/1 common

        AddDefaultCharset UTF-8
        TypesConfig conf/mime.types

        DavLockDB /usr/local/apache2/var/DavLock

        LDAPVerifyServerCert Off

        <Directory "/usr/local/apache2/webdav">
          Dav On
          Options Indexes FollowSymLinks
          AllowOverride None

          AuthType Basic
          AuthName "WebDAV"
          AuthBasicProvider ldap
          AuthLDAPURL "ldap://lldap.lldap.svc.cluster.local:3890/ou=people,dc=cia,dc=net?uid?sub?(objectClass=person)"
          AuthLDAPBindDN "uid=admin,ou=people,dc=cia,dc=net"
          AuthLDAPBindPassword "${LLDAP_BIND_PASSWORD}"
          Require valid-user
        </Directory>

        DocumentRoot "/usr/local/apache2/webdav"

        RequestHeader edit Destination ^https http early
        BrowserMatch "Microsoft Data Access Internet Publishing Provider" redirect-carefully
        BrowserMatch "MS FrontPage" redirect-carefully
        BrowserMatch "^WebDrive" redirect-carefully
        BrowserMatch "^WebDAVFS/1.[01234]" redirect-carefully
        BrowserMatch "^gnome-vfs/1.0" redirect-carefully
        BrowserMatch "^XML Spy" redirect-carefully
        BrowserMatch "^Dreamweaver-WebDAV-SCM1" redirect-carefully
        BrowserMatch "Konqueror/4" redirect-carefully
      CONF

      def initialize(
        name: "webdav",
        image: "httpd:2.4",
        storage: "5Gi",
        &block
      )
        config = Kube::Cluster["ConfigMap"].new {
          metadata.name = "#{name}-httpd-conf"
          data["httpd.conf"] = HTTPD_CONF
        }

        # ExternalSecret for LDAP bind password
        ldap_secret = Kube::Cluster["ExternalSecret"].new {
          metadata.name = "#{name}-ldap"
          spec.refreshInterval = "1h"
          spec.secretStoreRef = { kind: "ClusterSecretStore", name: "kubernetes" }
          spec.target = {
            name: "#{name}-ldap",
            creationPolicy: "Owner",
            deletionPolicy: "Retain",
          }
          spec.data = [
            { secretKey: "LLDAP_BIND_PASSWORD", remoteRef: { key: "openkrill-lldap", property: "LLDAP_LDAP_USER_PASS" } },
          ]
        }

        pvc = Kube::Cluster["PersistentVolumeClaim"].new {
          metadata.name = "#{name}-data"
          spec.accessModes = ["ReadWriteOnce"]
          spec.storageClassName = "csi-s3"
          spec.resources = { requests: { storage: storage } }
        }

        deployment = Kube::Cluster["Deployment"].new {
          metadata.name = name
          metadata.labels = { "app" => name }

          spec.replicas = 1
          spec.selector.matchLabels = { "app" => name }

          spec.template.metadata.labels = { "app" => name }
          spec.template.spec.securityContext = { fsGroup: 33 }
          spec.template.spec.containers = [
            {
              name: "httpd",
              image: image,
              command: ["sh", "-c", "mkdir -p /usr/local/apache2/webdav /usr/local/apache2/var && touch /usr/local/apache2/var/DavLock && chown -R www-data:www-data /usr/local/apache2/webdav /usr/local/apache2/var && httpd-foreground"],
              ports: [{ containerPort: 80, protocol: "TCP" }],
              env: [
                { name: "LLDAP_BIND_PASSWORD", valueFrom: { secretKeyRef: { name: "#{name}-ldap", key: "LLDAP_BIND_PASSWORD" } } },
              ],
              resources: {
                requests: { memory: "64Mi", cpu: "50m" },
                limits: { memory: "256Mi" },
              },
              securityContext: {
                privileged: true,
                capabilities: { add: ["SYS_ADMIN"] },
              },
              volumeMounts: [
                { name: "data", mountPath: "/usr/local/apache2/webdav" },
                { name: "httpd-conf", mountPath: "/usr/local/apache2/conf/httpd.conf", subPath: "httpd.conf", readOnly: true },
              ],
            },
          ]
          spec.template.spec.volumes = [
            { name: "data", persistentVolumeClaim: { claimName: "#{name}-data" } },
            { name: "httpd-conf", configMap: { name: "#{name}-httpd-conf" } },
          ]
        }

        service = Kube::Cluster["Service"].new {
          metadata.name = name
          metadata.labels = { "app" => name }
          spec.selector = { "app" => name }
          spec.ports = [{ port: 80, targetPort: 80, protocol: "TCP" }]
        }

        super(ldap_secret, config, pvc, deployment, service)
        instance_exec(&block) if block
      end
    end
  end
end
