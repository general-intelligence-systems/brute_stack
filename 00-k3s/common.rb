# frozen_string_literal: true


require 'bundler/setup'
require "active_support/all"
require 'scampi'
require 'kube/cluster'
require "open-uri"
require "yaml"
require "digest"
require "fileutils"

CLUSTER_DIR = File.expand_path(__dir__)

$LOAD_PATH.unshift "#{CLUSTER_DIR}/lib"

class ManifestCache
  def initialize(url)
    @url = url
  end

  def directory
    "#{CLUSTER_DIR}/.cache"
  end

  def file
    "#{directory}/#{Digest::SHA256.hexdigest(@url)}.yaml"
  end

  def read
    if File.exist?(file)
      File.read(file)
    else
      FileUtils.mkdir_p(directory)
      URI.open(@url).read.tap do |data|
        File.write(file, data)
      end
    end
  end
end

module URI
  def self.cache(url)
    ManifestCache.new(url)
  end
end
