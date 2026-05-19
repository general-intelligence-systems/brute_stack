# frozen_string_literal: true

require "bundler/setup"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "scampi"
require "a2a"
require "a2a/middleware"
require "console"
require "securerandom"
require "yaml"

agent_card = YAML.safe_load_file(File.join(__dir__, "agent_card.yml"))

agent = A2A::Agent.new do
  on "SendMessage" do
    use A2A::Middleware::ExtractMessage
    respond_with -> (env) {
      request    = env["a2a.request"]
      text       = env["a2a.message"]
      context_id = request.message.context_id
      context_id = context_id.to_s.empty? ? SecureRandom.uuid : context_id
      task_id    = SecureRandom.uuid

      Console.info(self) { "SendMessage Received: #{text}" }

      A2A::Schema["Send Message Response"].new(
        task: {
          "id"        => task_id,
          "contextId" => context_id,
          "status"    => {
            "state"     => "TASK_STATE_COMPLETED",
            "timestamp" => Time.now.utc.iso8601(3)
          },
          "artifacts" => [
            {
              "artifactId" => SecureRandom.uuid,
              "name"       => "echo-response",
              "parts"      => [{ "text" => "Echo: #{text}" }],
            }
          ],
        }
      )
    }
  end
end

app = A2A::Server.new(agent_card: agent_card)
app.register(agent)

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "agent-echo")
end

Console.info(self) { "Echo Agent starting..." }
Console.info(self) { "Agent card: #{agent_card["name"]}" }

run app
