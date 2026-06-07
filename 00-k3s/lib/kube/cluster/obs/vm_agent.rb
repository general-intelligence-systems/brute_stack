# frozen_string_literal: true

require 'kube/cluster/obs/victoria_logs'

module Kube
  module Cluster
    module Obs
      class VMAgent < Kube::Cluster['VMAgent']
        def initialize(name:, remote_write_url:, scrape_interval: '30s', select_all: true, &block)
          super() {
            metadata.name           = name
            spec.selectAllByDefault = select_all
            spec.scrapeInterval     = scrape_interval
            spec.remoteWrite        = [{ url: remote_write_url }]
            instance_exec(&block) if block
          }
        end
      end
    end
  end
end
