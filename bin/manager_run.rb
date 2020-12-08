#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
manager = Speedtest::Manager.new(logger)

logger.info "Loading servers lists"
servers_speedtest = manager.load_speedtest_server_list
servers_global = manager.load_global_server_list

logger.info "Sorting servers lists"
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip
ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

servers_speedtest_maxmind = manager.sort_and_filter_server_list(servers_speedtest, maxmind_geopoint,
                                                        keep_num_servers: 20, min_latency: 7, skip_fqdns: [])
servers_speedtest_ipstack = manager.sort_and_filter_server_list(servers_speedtest, ipstack_geopoint,
                                                        keep_num_servers: 20, min_latency: 7, skip_fqdns: [])

geopoint = maxmind_geopoint
servers_speedtest = servers_speedtest_maxmind
if servers_speedtest_ipstack.min_latency < servers_speedtest_maxmind.min_latency
  logger.info "Using ipstack geopoint #{servers_speedtest_ipstack.min_latency} < #{servers_speedtest_maxmind.min_latency}"
  geopoint = ipstack_geopoint
  servers_speedtest = servers_speedtest_ipstack
else
  logger.info "Using maxmind geopoint #{servers_speedtest_maxmind.min_latency} <= #{servers_speedtest_ipstack.min_latency}"
end

servers_global = manager.sort_and_filter_server_list(servers_global, geopoint,
                                                        keep_num_servers: 20, min_latency: 7, skip_fqdns: [])

servers = manager.merge_server_lists(servers_speedtest, servers_global)
servers.each { |s| logger.debug [ s.url, s.geopoint, s.latency ].ai }

logger.info "Running transfers"
manager.run_each_transfer(servers, 2, num_threads: 2, download_size: 500, upload_size: 524288) do |transfer|
  ap transfer
end

