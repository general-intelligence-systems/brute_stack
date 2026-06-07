# frozen_string_literal: true

require "async/service/generic"
require "async/service/supervisor/supervised"
require "a2a"
require "console"
require "erb"
require "faraday"
require "json"
require "securerandom"
require "time"

module Heartbeat
  module Environment
    def service_class = Heartbeat::Service
    def soul_path = ""
    def prompt = "<%= soul %>"
    def a2a_url = "http://localhost:4000"
    def notify_url = "http://localhost:5000/_heartbeat/notify"
    def notify_user = "@demo:localhost"
    def interval = 30 # seconds
  end

  class Service < Async::Service::Generic
    def setup(container)
      super

      # Single worker, that restarts on crash.
      container.run(count: 1, restart: true) do |instance|

        env = self.environment.evaluator

        a2a_client = A2A::Client.new(env.a2a_url)

        instance.ready!

        Console.info(self) { "Heartbeat ticking every #{env.interval}s" }

        loop do
          sleep env.interval

          prompt = ERB.new(env.prompt).result_with_hash(
            soul: File.read(env.soul_path),
            time: Time.now.utc.iso8601
          )

          response = a2a_client.send_message(
            message: {
              message_id: SecureRandom.uuid,
              context_id: "heartbeat",
              role:       "ROLE_USER",
              parts:      [{ "text" => prompt }],
            }
          )

          text = response.task.artifacts
            &.flat_map(&:parts)
            &.filter_map(&:text)
            &.join("\n")
            &.strip

          if text != "HEARTBEAT_OK"
            Console.info(self) { "Heartbeat produced output, notifying #{env.notify_user}" }

            Faraday.post(env.notify_url) do |req|
              req.headers["content-type"] = "application/json"
              req.body = JSON.generate(text: text, user: env.notify_user)
            end
          else
            Console.info(self) { "Heartbeat OK" }
          end
        rescue => error
          Console.error(self) { "Heartbeat send failed: #{error.message}" }
        end
      end
    end
  end
end

service "heartbeat" do
  include Heartbeat::Environment
  include Async::Service::Supervisor::Supervised

  interval 30 # seconds

  a2a_url "http://0.0.0.0:4000"

  notify_url "http://localhost:5000/_heartbeat/notify"

  notify_user "@demo:localhost"

  soul_path {
    File.expand_path("SOUL.md", root)
  }

  prompt {
    <<~PROMPT
      # Heartbeat Check

      Current time: <%= time %>

      You are a proactive AI assistant. This is a scheduled heartbeat check.
      Review the following tasks and execute any necessary actions using available skills.

      <%= soul %>

      If nothing needs attention respond ONLY with:
      HEARTBEAT_OK
    PROMPT
  }
end
