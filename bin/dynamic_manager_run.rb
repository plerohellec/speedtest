#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new

logger.info "Loading servers lists"
servers_dynamic = manager.load_dynamic_server_list

logger.info "Sorting servers lists"
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip
ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

servers_dynamic_maxmind = manager.sort_and_filter_server_list(servers_dynamic, maxmind_geopoint,
                                                        keep_num_servers: 20, min_latency: 7, skip_fqdns: [])
servers_dynamic_ipstack = manager.sort_and_filter_server_list(servers_dynamic, ipstack_geopoint,
                                                        keep_num_servers: 20, min_latency: 7, skip_fqdns: [])

geopoint = maxmind_geopoint
servers_dynamic = servers_dynamic_maxmind
if servers_dynamic_ipstack.min_latency < servers_dynamic_maxmind.min_latency
  logger.info "Using ipstack geopoint #{servers_dynamic_ipstack.min_latency} < #{servers_dynamic_maxmind.min_latency}"
  geopoint = ipstack_geopoint
  servers_dynamic = servers_dynamic_ipstack
else
  logger.info "Using maxmind geopoint #{servers_dynamic_maxmind.min_latency} <= #{servers_dynamic_ipstack.min_latency}"
end

servers_dynamic.each { |s| logger.debug [ s.url, s.geopoint, s.min_latency ].ai }

logger.info "Running transfers"
manager.run_each_transfer(servers_dynamic, 2, num_threads: 2, download_size: 500, upload_size: 524288) do |transfer|
  ap transfer
end

