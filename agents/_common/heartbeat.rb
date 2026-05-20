# frozen_string_literal: true

require "async/service/generic"
require "async/service/supervisor/supervised"
require "a2a"
require "console"
require "erb"
require "securerandom"
require "time"

module Heartbeat
  module Environment
    def service_class = Heartbeat::Service
    def soul_path = "" # File.expand_path("../SOUL.md", root)
    def prompt = "<%= soul %>"
    def a2a_url = "http://localhost:4000"
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

        loop
          sleep env.interval

          prompt = ERB.new(env.prompt).render_with_hash(
            soul: File.read(env.soul_path),
            now: Time.now.utc.iso8601
          )

          a2a_client.send_message(
            message: {
              message_id: SecureRandom.uuid,
              context_id: "heartbeat", # this is how the A2A agent knows to behave differently
              role:       "ROLE_USER",
              parts:      [{ "text" => prompt }],
            }
          )
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

  soul_path {
    File.expand_path("../SOUL.md", root)
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
