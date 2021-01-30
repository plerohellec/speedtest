#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new

list_name = ENV.fetch('LIST', 'speedtest')

logger.info "Loading servers lists for #{list_name}"
servers = manager.load_server_list(list_name)

logger.info "Sorting servers lists"
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip
ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

options = { keep_num_servers: 20, min_latency: 7, skip_fqdns: [] }
servers_maxmind = manager.sort_and_filter_server_list(servers, maxmind_geopoint, options)
servers_ipstack = manager.sort_and_filter_server_list(servers, ipstack_geopoint, options)

geopoint = maxmind_geopoint
servers = servers_maxmind
if servers_ipstack.min_latency < servers_maxmind.min_latency
  logger.info "Using ipstack geopoint #{servers_ipstack.min_latency} < #{servers_maxmind.min_latency}"
  geopoint = ipstack_geopoint
  servers = servers_ipstack
else
  logger.info "Using maxmind geopoint #{servers_maxmind.min_latency} <= #{servers_ipstack.min_latency}"
end

servers.each { |s| logger.debug [ s.url, s.geopoint, s.latency, s.origin ].ai }

logger.info "Running transfers"
transfers = []
manager.run_each_transfer(servers, 2, num_threads: 2, download_size: 500, upload_size: 524288) do |transfer|
  transfers << transfer
end
transfers.each { |t| puts t.pretty_print }

