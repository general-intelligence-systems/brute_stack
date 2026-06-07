# Renders the Ruby kube_cluster manifests to YAML and applies them to the k3s cluster.
# Build context is the 00-k3s folder (manifests.rb, manifests/, lib/, common.rb, Gemfile).

FROM ruby:3.4-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates build-essential libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/v1.31.4/bin/linux/amd64/kubectl" && \
    chmod +x /usr/local/bin/kubectl

WORKDIR /work

COPY Gemfile ./
RUN bundle install

COPY . .
RUN chmod +x applier/entrypoint.sh

ENTRYPOINT ["applier/entrypoint.sh"]
