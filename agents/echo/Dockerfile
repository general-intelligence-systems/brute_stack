# Build context is ./agents (one level up), not this directory.
# docker build -f agents/echo/Dockerfile agents/

FROM ghcr.io/ruby/ruby:latest AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libyaml-dev \
    libssl-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY echo/Gemfile echo/Gemfile.lock ./
RUN bundle install

FROM ghcr.io/ruby/ruby:latest

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=build /usr/local/bin /usr/local/bin
COPY _common ./_common
COPY echo/ ./

CMD ["bundle", "exec", "falcon", "host", "_common/falcon.rb"]
