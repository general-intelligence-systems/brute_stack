# frozen_string_literal: true

require "async/service/supervisor/monitor"
require "async/http/server"
require "async/http/endpoint"
require "protocol/http/response"

# A supervisor monitor that exposes HTTP health check endpoints.
#
# Runs an HTTP server on a dedicated port inside the supervisor process.
# Tracks worker registrations via the supervisor IPC bus and reports
# healthy when at least one worker is connected.
#
# Endpoints:
#   GET /healthz, /livez  -- 200 if workers connected, 503 if not
#   GET /readyz           -- 200 if workers connected, 503 if not
#   GET /statusz          -- JSON with worker count and service names
#
class HealthMonitor < Async::Service::Supervisor::Monitor
  def initialize(port: 8080, interval: 5)
    super(interval: interval)
    @port = port
    @workers = {}
    @guard = Mutex.new
  end

  def register(supervisor_controller)
    @guard.synchronize { @workers[supervisor_controller.id] = supervisor_controller }
  end

  def remove(supervisor_controller)
    @guard.synchronize { @workers.delete(supervisor_controller.id) }
  end

  def healthy?
    @guard.synchronize { @workers.any? }
  end

  def as_json
    @guard.synchronize do
      {
        healthy: healthy?,
        workers: @workers.size,
        services: @workers.values.map { |c| c.state[:name] }.uniq,
      }
    end
  end

  def run(parent: Async::Task.current)
    super

    endpoint = Async::HTTP::Endpoint.parse("http://0.0.0.0:#{@port}")

    parent.async do
      server = Async::HTTP::Server.for(endpoint) do |request|
        case request.path
        when "/healthz", "/livez"
          status = healthy? ? 200 : 503
          body = healthy? ? "ok" : "no workers"
          Protocol::HTTP::Response[status, {"content-type" => "text/plain"}, [body]]
        when "/readyz"
          status = healthy? ? 200 : 503
          body = healthy? ? "ready" : "not ready"
          Protocol::HTTP::Response[status, {"content-type" => "text/plain"}, [body]]
        when "/statusz"
          Protocol::HTTP::Response[200, {"content-type" => "application/json"}, [as_json.to_json]]
        else
          Protocol::HTTP::Response[404, {}, ["not found"]]
        end
      end
      server.run
    end
  end
end
