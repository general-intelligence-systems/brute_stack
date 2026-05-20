#!/usr/bin/env falcon-host

require "falcon/environment/rack"
require "async/service/supervisor"
require_relative "health_monitor"

service "agent2agent" do
  include Falcon::Environment::Rack
  include Async::Service::Supervisor::Supervised

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:4000")
  end
end

service "matrix-appservice" do
  include Falcon::Environment::Rack
  include Async::Service::Supervisor::Supervised

  rackup_path do
    File.expand_path("_common/appservice.ru", root)
  end

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:5000")
  end
end

service "supervisor" do
  include Async::Service::Supervisor::Environment

  monitors do
    max_per_worker = Integer(ENV.fetch("MEMORY_LIMIT_PER_WORKER", 134217728))
    max_total      = Integer(ENV.fetch("MEMORY_LIMIT_TOTAL", 536870912))

    [
      Async::Service::Supervisor::MemoryMonitor.new(
        interval: 10,
        maximum_size_limit: max_per_worker,
        total_size_limit: max_total,
      ),
      HealthMonitor.new(port: 8080, interval: 5),
    ]
  end
end
