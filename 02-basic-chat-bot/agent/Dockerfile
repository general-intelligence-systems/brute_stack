# Self-contained agent image. Build context is this folder (./agent),
# which carries the agent code plus its own copy of _common/.

FROM ghcr.io/ruby/ruby:latest AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libyaml-dev \
    libssl-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM ghcr.io/ruby/ruby:latest

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=build /usr/local/bin /usr/local/bin
COPY . ./

CMD ["bundle", "exec", "falcon", "host", "service.rb"]
