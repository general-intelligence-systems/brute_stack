# frozen_string_literal: true

require "bundler/setup"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "scampi"
require "brute"
require "a2a"
require "a2a/middleware"
require "console"
require "securerandom"
require "yaml"
require "async/semaphore"
require "fileutils"
require_relative "_common/steering_check"

agent_card = YAML.safe_load_file(File.join(__dir__, "agent_card.yml"))

Brute.provider = :ollama
Brute.config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/v1")

# Fetch available models from the Ollama server so the registry knows about them
RubyLLM.models.refresh!

LOCK = Async::Semaphore.new(1)
HEARTBEAT_LOCK = Async::Semaphore.new(1)
STEERING_QUEUE = {}
RUNNING = {}

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

      push_url = request.configuration&.task_push_notification_config&.url

      run_llm = -> {
        llm = Brute::Agent.new(
          provider: :ollama,
          model:    "qwen2.5:0.5b",
          tools:    [],
        ) do
          use Brute::Middleware::SystemPrompt
          use SteeringCheck,
            queue: STEERING_QUEUE,
            context_id: context_id,
            lock: LOCK
  
          run Brute::Middleware::LLMCall.new
        end
  
        Brute::Session.new(path: "/app/sessions/#{context_id}").then do |session|
          session.user(text) if context_id == "heartbeat"
          llm.call(session)

          session.last.content
        end
      }

      heartbeat_completed_response = -> (artifact) {
        A2A::Schema["Send Message Response"].new(
          task: {
            id:         task_id,
            context_id: context_id,
            status: {
              state: "TASK_STATE_COMPLETED",
              timestamp: Time.now.utc.iso8601(3),
            },
            artifacts: [
              {
                artifactId: SecureRandom.uuid,
                name: context_id == "heartbeat" ? "heartbeat-response" : "brute-response",
                parts: [{ text: artifact }],
              }
            ],
          }.compact,
        )
      }

      heartbeat_failed_response = -> (error) {
        A2A::Schema["Send Message Response"].new(
          task: {
            id:         task_id,
            context_id: context_id,
            status: {
              state: "TASK_STATE_FAILED",
              timestamp: Time.now.utc.iso8601(3),
            },
            metadata: {
              error: error.message,
            },
          },
        )
      }

      push_notification_callback = -> (state:, artifact: nil, error: nil) {
        Faraday.post(push_url) do |req|
          req.headers["content-type"] = "application/json"
          req.body = JSON.generate(
            task: {
              id: task_id,
              contextId: context_id,
              status: {
                state: state,
                timestamp: Time.now.utc.iso8601(3),
              },
              artifacts: artifact && [
                {
                  artifactId: SecureRandom.uuid,
                  name: "brute-response",
                  parts: [{ text: artifact }],
                }
              ],
              metadata: error && { error: error },
            }.compact
          )
        end
      }

      if context_id == "heartbeat"
        HEARTBEAT_LOCK.acquire do
          if RUNNING.any?
            heartbeat_completed_response.call("HEARTBEAT_OK")
          else
            FileUtils.rm_f("/app/sessions/heartbeat")
            begin
              heartbeat_completed_response.call(run_llm.call)
            rescue => error
              Console.error(self, error)
              heartbeat_failed_response.call(error)
            ensure
              FileUtils.rm_f("/app/sessions/heartbeat")
            end
          end
        end
      else
        LOCK.acquire do
          STEERING_QUEUE[context_id] ||= []
          STEERING_QUEUE[context_id] << text
        
          RUNNING[context_id] ||= Async do
            begin
              artifact = run_llm.call

              push_notification_callback.call(
                state: "TASK_STATE_COMPLETED",
                artifact: artifact,
              )
            rescue => error
              push_notification_callback.call(
                state: "TASK_STATE_FAILED",
                error: error.message,
              )
            ensure
              LOCK.acquire do
                RUNNING.delete(context_id)
                STEERING_QUEUE.delete(context_id)
              end
            end
          end
        end

        A2A::Schema["Send Message Response"].new(
          task: {
            id:         task_id,
            context_id: context_id,
            status: {
              state: "TASK_STATE_SUBMITTED",
              timestamp: Time.now.utc.iso8601(3)
            },
          }
        )
      end
    }
  end
end

app = A2A::Server.new(agent_card: agent_card)
app.register(agent)

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "agent-brute")
end

Console.info(self) { "Brute Agent starting..." }
Console.info(self) { "Agent card: #{agent_card["name"]}" }

run app
