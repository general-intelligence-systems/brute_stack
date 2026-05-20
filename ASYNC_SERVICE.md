The [deep-wiki](https://deepwiki.com/socketry/async-service) provides a really good explanation of [async-service](https://github.com/socketry/async-service)

## Async Service Architecture:

```
Async::Service::Environment - How do I define my settings?
  |
  | provides config to
  v
Async::Service::Generic - How do I run my logic?
  |
  | is managed by
  v
Async::Service::Control - How do I manage the lifecycle?
  |
  | uses for decisions
  v
Async::Service::Policy - How do I handle failure?
```

[Async::Service::Controller](https://github.com/socketry/async-service/blob/main/lib/async/service/controller.rb) provides 3 methods:
* start
* setup(controller)
* stop(graceful = true)

`start` and `stop` are run before and after the container is run. The `setup` method actually calls `container.run`.

```ruby
def setup(controller)
  controller.run(count: 1, **) do |instance|
    loop do
      # this is the actual service logic...
    end
  end
end
```

### Environment DSL

You put your code in a `services.rb` file typically. Although [falcon](https://github.com/sockery/falcon) uses `falcon.rb` for legacy reasons.
You're provided with some helper methods to build your services. Below you can see usage of `environment do; end` and `service do; end`.

```ruby
# services.rb
LogLevel = environment do
  log_level :info
end

service "web-server" do
  include LogLevel
  service_class MyWebApp::Service
  port 8080
end
```

The DSL is implemented through (Async::Service::Environment::Builder)[https://github.com/socketry/async-service/blob/main/lib/async/service/environment.rb#L13], which uses `method_missing` to dynamically define configuration methods.

