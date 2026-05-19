# frozen_string_literal: true

require "bundler/setup"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "a2a"
require "async/matrix"
require "securerandom"

Bot    = Async::Matrix::ApplicationService::Bot
Config = Async::Matrix::ApplicationService::Config
Server = Async::Matrix::ApplicationService::Server
MatrixClient = Async::Matrix::Client

AGENT_NAME = ENV.fetch("AGENT_NAME", "unknown")
AGENT_URL  = ENV.fetch("A2A_URL", "http://localhost:9292")
a2a_client = A2A::Client.new(AGENT_URL)

bot_config = Config.new(
  "homeserver" => {
    "address" => ENV.fetch("HOMESERVER_ADDRESS", "http://matrix-stack-synapse.ai.svc.cluster.local:8008"),
    "domain"  => ENV.fetch("HOMESERVER_DOMAIN", "kremlin.email"),
  },
  "appservice" => {
    "as_token" => ENV.fetch("AS_TOKEN"),
    "hs_token" => ENV.fetch("HS_TOKEN"),
    "hostname" => "0.0.0.0",
    "port"     => 3000,
    "bot"      => { "username" => AGENT_NAME },
  }
)

matrix_bot = Bot.new(MatrixClient.new(bot_config)) do
  on "m.room.member" do |event|
    if event.content.membership == "invite" &&
       event.state_key == client.config.bot_mxid

      Console.info(self) { "Invited to #{event.room_id} by #{event.sender} -- joining" }

      join_room(event.room_id)
    end
  end

  on "m.room.message", msgtype: "m.text", not_from: :self do |event|
    Console.info(self) {
      "Message from #{event.sender} in #{event.room_id}: #{event.content.body[0..100]}"
    }

    a2a_client.send_message(
      message: {
        "messageId" => event.event_id || SecureRandom.uuid,
        "role"      => "ROLE_USER",
        "parts"     => [{ "text" => event.content.body }],
        "contextId" => event.room_id,
      },
      configuration: {
        "taskPushNotificationConfig" => {
          "url" => "http://localhost:3000/_a2a/push",
        }
      }
    ).then do |response|
      case response.task.status.state
      in "TASK_STATE_COMPLETED"
        text = response.task.artifacts
          &.flat_map(&:parts)
          &.filter_map(&:text)
          &.join("\n")
        send_notice(event.room_id, text) unless text.nil? || text.empty?
      in "TASK_STATE_FAILED"
        send_notice(event.room_id, "Something went wrong...")
      in "TASK_STATE_SUBMITTED" | "TASK_STATE_WORKING"
        Console.info(self) { "Task submitted, awaiting push notification" }
      end
    end
  end
end

push_handler = ->(env) {
  body    = Rack::Request.new(env).body.read
  payload = JSON.parse(body)
  task    = payload["task"]

  context_id = task["contextId"]
  state      = task.dig("status", "state")

  Console.info(self) { "Push notification received: #{state} for #{context_id}" }

  case state
  in "TASK_STATE_COMPLETED"
    text = task["artifacts"]
      &.flat_map { |a| a["parts"] || [] }
      &.filter_map { |p| p["text"] }
      &.join("\n")
    matrix_bot.client.send_notice(context_id, text) if text && !text.empty?
  in "TASK_STATE_FAILED"
    error = task.dig("metadata", "error") || "Unknown error"
    matrix_bot.client.send_notice(context_id, "Something went wrong: #{error}")
  else
    Console.info(self) { "Ignoring push notification with state: #{state}" }
  end

  [200, { "content-type" => "application/json" }, ['{"ok":true}']]
}

matrix_server = Server.new(hs_token: bot_config.appservice.hs_token)
matrix_server.register(matrix_bot)

agent_name = bot_config.appservice.bot.username
domain     = bot_config.homeserver.domain

Console.info(self) { "Matrix Appservice starting for @#{agent_name}:#{domain}" }
Console.info(self) { "Forwarding messages to A2A agent at #{AGENT_URL}" }

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "agent-#{AGENT_NAME}") + "-appservice"
end

app = Rack::Builder.new do
  map "/_a2a/push" do
    run push_handler
  end

  map "/" do
    run matrix_server
  end
end

run app
