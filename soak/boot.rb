# Every process in the soak test loads this file first. It points the real
# orchestrator at the clustered Valkey and the fake website, and shortens the
# timings so that a short run still exercises every recovery path.
$stdout.sync = true
$stderr.sync = true

ENV['EXERCISM_ENV'] ||= 'test'
ENV['EXERCISM_CI'] ||= 'true'
ENV['APP_ENV'] ||= 'test'

require 'bundler/setup'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'orchestrator'
require 'redis-clustering'

module Soak
  NODES = ENV.fetch('SOAK_REDIS_NODES').split(',').map { |node| "redis://#{node}" }
  SPI_URL = ENV.fetch('SOAK_SPI_URL', 'http://127.0.0.1:4100')
end

module Exercism
  # In production the orchestrator talks to clustered Valkey through
  # Redis::Cluster, so the soak test does the same.
  def self.redis_client(_url) = Redis::Cluster.new(nodes: Soak::NODES)
end

Exercism.config.define_singleton_method(:spi_url) { Soak::SPI_URL }

module Orchestrator
  class Configuration
    def lease_seconds = 8
    def retry_seconds = 1
    def deadline_grace_seconds = 3
    def promotion_timeout_seconds = 3
  end
end
