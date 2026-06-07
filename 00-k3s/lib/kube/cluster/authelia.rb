# frozen_string_literal: true

module Kube
  module Cluster
    class Authelia < Kube::Cluster["ConfigMap"]
      PROVIDER_ID = "0870CA2BF7272852F5DAB70319"

      CONFIGURATION = <<~YAML
        ---
        # yaml-language-server: $schema=https://www.authelia.com/schemas/v4.39/json-schema/configuration.json
        theme: 'light'
        default_2fa_method: ''
        server:
          address: 'tcp://0.0.0.0:9091/'
          asset_path: ''
          headers:
            csp_template: ""
          buffers:
            read: 16384
            write: 16384
          timeouts:
            read: '6 seconds'
            write: '6 seconds'
            idle: '30 seconds'
          endpoints:
            enable_pprof: false
            enable_expvars: false
            authz:
              basic-auth:
                implementation: 'ForwardAuth'
                authn_strategies:
                  - name: 'HeaderAuthorization'
                    scheme_basic_cache_lifespan: 0
              forward-auth:
                implementation: 'ForwardAuth'
                authn_strategies:
                  - name: 'HeaderAuthorization'
                    scheme_basic_cache_lifespan: 0
                  - name: 'CookieSession'
        log:
          level: 'info'
          format: 'text'
          file_path: ''
          keep_stdout: true
        telemetry:
          metrics:
            enabled: true
            address: 'tcp://0.0.0.0:9959'
            buffers:
              read: 4096
              write: 4096
            timeouts:
              read: '6 seconds'
              write: '6 seconds'
              idle: '30 seconds'
        identity_validation:
          elevated_session:
            code_lifespan: '5 minutes'
            elevation_lifespan: '10 minutes'
            characters: 8
            require_second_factor: false
            skip_second_factor: false
          reset_password:
            jwt_lifespan: '5 minutes'
            jwt_algorithm: 'HS256'
        totp:
          disable: false
          issuer: 'Authelia'
          skew: 1
          secret_size: 32
          algorithm: 'SHA1'
          digits: 6
          period: 30
          allowed_algorithms:
            - 'SHA1'
          allowed_digits:
            - 6
          allowed_periods:
            - 30
        webauthn:
          disable: false
          enable_passkey_login: false
          display_name: 'Authelia'
          attestation_conveyance_preference: 'indirect'
          timeout: '60 seconds'
          filtering:
            permitted_aaguids: []
            prohibited_aaguids: []
            prohibit_backup_eligibility: false
          selection_criteria:
            attachment: ''
            discoverability: 'preferred'
            user_verification: 'preferred'
          metadata:
            enabled: false
            cache_policy: 'strict'
            validate_trust_anchor: true
            validate_entry: true
            validate_entry_permit_zero_aaguid: false
            validate_status: true
            validate_status_permitted: []
            validate_status_prohibited: []
        ntp:
          address: 'udp://time.cloudflare.com:123'
          version: 4
          max_desync: '3 seconds'
          disable_startup_check: false
          disable_failure: false
        authentication_backend:
          password_reset:
            disable: false
            custom_url: ''
          password_change:
            disable: false
          refresh_interval: '5 minutes'
          ldap:
            implementation: 'lldap'
            address: 'ldap://lldap.lldap.svc.cluster.local:3890'
            timeout: '5 seconds'
            start_tls: false
            tls:
              server_name: ''
              skip_verify: false
              minimum_version: 'TLS1.2'
              maximum_version: 'TLS1.3'
            pooling:
              enable: false
              count: 5
              retries: 2
              timeout: '10 seconds'
            base_dn: 'dc=cia,dc=net'
            group_search_mode: 'filter'
            permit_referrals: false
            permit_unauthenticated_bind: false
            permit_feature_detection_failure: false
            user: 'UID=admin,OU=people,dc=cia,dc=net'
            attributes:
              distinguished_name: ''
              username: ''
              display_name: ''
              family_name: ''
              given_name: ''
              middle_name: ''
              nickname: ''
              gender: ''
              birthdate: ''
              website: ''
              profile: ''
              picture: ''
              zoneinfo: ''
              locale: ''
              phone_number: ''
              phone_extension: ''
              street_address: ''
              locality: ''
              region: ''
              postal_code: ''
              country: ''
              mail:  ''
              member_of:  ''
              group_name:  ''
        password_policy:
          standard:
            enabled: false
            min_length: 8
            max_length: 0
            require_uppercase: false
            require_lowercase: false
            require_number: false
            require_special: false
          zxcvbn:
            enabled: false
            min_score: 0
        session:
          name: 'authelia_session'
          same_site: 'lax'
          inactivity: '4h'
          expiration: '12h'
          remember_me: '1M'
          cookies:
            - domain: 'cia.net'
              authelia_url: 'https://auth.cia.net'
            - domain: 'kremlin.email'
              authelia_url: 'https://auth.kremlin.email'
        regulation:
          modes:
          - 'user'
          max_retries: 3
          find_time: '2 minutes'
          ban_time: '5 minutes'
        storage:
          postgres:
            address: 'tcp://postgres-rw.cloudnative-pg.svc.cluster.local:5432'
            servers: []
            timeout: '5 seconds'
            database: 'authelia'
            schema: 'public'
            username: 'app'
        notifier:
          disable_startup_check: false
          filesystem:
            filename: '/config/notification.txt'
        identity_providers:
          oidc:
            lifespans:
              access_token: '1 hour'
              refresh_token: '1 hour and 30 minutes'
              id_token: '1 hour'
              authorize_code: '1 minute'
              device_code: '10 minutes'
            enforce_pkce: 'public_clients_only'
            enable_pkce_plain_challenge: false
            enable_client_debug_messages: false
            enable_jwt_access_token_stateless_introspection: false
            minimum_parameter_entropy: 8
            discovery_signed_response_alg: ''
            discovery_signed_response_key_id: ''
            require_pushed_authorization_requests: false
            jwks:
              - algorithm: 'RS256'
                use: 'sig'
                key: {{ secret "/secrets/authelia/identity_providers.oidc.jwks.0.key" | mindent 10 "|" | msquote }}
            cors:
              endpoints:
              - 'authorization'
              - 'token'
              - 'revocation'
              - 'introspection'
              - 'userinfo'
              allowed_origins_from_client_redirect_uris: true
            clients:
              - client_id: 'vclusterplatform'
                client_name: 'vCluster Platform'
                client_secret: '$plaintext$vclusterplatform-oidc-client-secret-cia.net'
                public: false
                redirect_uris:
                  - 'https://vcluster.cia.net/auth/oidc/callback'
                scopes:
                  - 'openid'
                  - 'profile'
                  - 'email'
                  - 'groups'
                grant_types:
                  - 'authorization_code'
                response_types:
                  - 'code'
                authorization_policy: 'one_factor'
                consent_mode: 'pre-configured'
                require_pushed_authorization_requests: false
                require_pkce: false
                pkce_challenge_method: ''
                authorization_signed_response_alg: 'RS256'
                authorization_signed_response_key_id: ''
                authorization_encrypted_response_key_id: ''
                authorization_encrypted_response_alg: ''
                authorization_encrypted_response_enc: ''
                id_token_signed_response_alg: 'RS256'
                id_token_signed_response_key_id: ''
                id_token_encrypted_response_key_id: ''
                id_token_encrypted_response_alg: ''
                id_token_encrypted_response_enc: ''
                access_token_signed_response_alg: 'none'
                access_token_signed_response_key_id: ''
                access_token_encrypted_response_key_id: ''
                access_token_encrypted_response_alg: ''
                access_token_encrypted_response_enc: ''
                userinfo_signed_response_alg: 'none'
                userinfo_signed_response_key_id: ''
                userinfo_encrypted_response_key_id: ''
                userinfo_encrypted_response_alg: ''
                userinfo_encrypted_response_enc: ''
                introspection_signed_response_alg: 'none'
                introspection_signed_response_key_id: ''
                introspection_encrypted_response_key_id: ''
                introspection_encrypted_response_alg: ''
                introspection_encrypted_response_enc: ''
                introspection_endpoint_auth_method: 'client_secret_basic'
                introspection_endpoint_auth_signing_alg: 'RS256'
                request_object_signing_alg: ''
                request_object_encryption_alg: 'none'
                request_object_encryption_enc: ''
                token_endpoint_auth_method: 'client_secret_basic'
                token_endpoint_auth_signing_alg: ''
                revocation_endpoint_auth_method: 'client_secret_basic'
                revocation_endpoint_auth_signing_alg: 'RS256'
                pushed_authorization_request_endpoint_auth_method: 'client_secret_basic'
                pushed_authorization_request_endpoint_auth_signing_alg: 'RS256'
              - client_id: 'matrix-authentication-service'
                client_name: 'Matrix Authentication Service'
                client_secret: '$plaintext$matrix-authentication-service-oidc-client-secret-kremlin.email'
                public: false
                redirect_uris:
                  - 'https://auth-chat.kremlin.email/upstream/callback/#{PROVIDER_ID}'
                scopes:
                  - 'openid'
                  - 'profile'
                  - 'email'
                grant_types:
                  - 'authorization_code'
                  - 'refresh_token'
                response_types:
                  - 'code'
                authorization_policy: 'one_factor'
                consent_mode: 'pre-configured'
                token_endpoint_auth_method: 'client_secret_basic'
        access_control:
          default_policy: 'one_factor'
        ...
      YAML

      def initialize(&block)
        super() {
          metadata.name = "authelia"
          metadata.namespace = "authelia"
          data["configuration.yaml"] = CONFIGURATION
          instance_exec(&block) if block
        }
      end
    end
  end
end
