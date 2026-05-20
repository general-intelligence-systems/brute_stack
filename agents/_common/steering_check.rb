# frozen_string_literal: true

class SteeringCheck
  def initialize(app, queue:, context_id:, lock:)
    @app = app
    @queue = queue
    @context_id = context_id
    @lock = lock
  end

  def call(env)
    @lock.acquire do
      queue  = @queue[@context_id] || []
      length = @queue[@context_id]&.length || 0

      queue.shift(length).each do |text|
        env[:messages].user(text)
      end
    end

    @app.call(env)
  end
end

