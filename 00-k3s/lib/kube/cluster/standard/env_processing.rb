module Kube
  module Cluster
    module Standard
      module EnvProcessing
        # Convert an env hash into a Kubernetes env array.
        #
        # String/numeric values become plain env vars:
        #   "FOO" => "bar"  =>  { name: "FOO", value: "bar" }
        #
        # ExternalSecret::TemplateRef values become secretKeyRef env vars
        # and register the template entry on the ExternalSecret:
        #   "FOO" => secret.template("{{ .bar }}")
        #     =>  { name: "FOO", valueFrom: { secretKeyRef: { name: "secret-name", key: "FOO" } } }
        #
        def self.process(env)
          return env if env.is_a?(Array)
          return [] if env.nil?

          env.map do |key, value|
            key = key.to_s

            if value.is_a?(ExternalSecret::TemplateRef)
              value.secret.register_template!(key, value.template_value)
              { name: key, valueFrom: { secretKeyRef: { name: value.secret.secret_name, key: key } } }
            else
              { name: key, value: value.to_s }
            end
          end
        end
      end
    end
  end
end
