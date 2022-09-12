#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

MIN_LATENCY = 7

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new

logger.info "Loading servers lists"
servers_speedtest = manager.load_speedtest_server_list
servers_dynamic = manager.load_dynamic_server_list
servers_global = manager.load_global_server_list

logger.info "Sorting servers lists"
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip
ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

servers_speedtest_maxmind = manager.sort_and_filter_server_list(servers_speedtest, maxmind_geopoint,
                                                        keep_num_servers: 20, min_latency: MIN_LATENCY, skip_fqdns: [])
servers_speedtest_ipstack = manager.sort_and_filter_server_list(servers_speedtest, ipstack_geopoint,
                                                        keep_num_servers: 20, min_latency: MIN_LATENCY, skip_fqdns: [])
if servers_speedtest.any?
  geopoint = maxmind_geopoint
  servers_speedtest = servers_speedtest_maxmind
  if servers_speedtest_ipstack.min_latency < servers_speedtest_maxmind.min_latency
    logger.info "Using ipstack geopoint #{servers_speedtest_ipstack.min_latency} < #{servers_speedtest_maxmind.min_latency}"
    geopoint = ipstack_geopoint
    servers_speedtest = servers_speedtest_ipstack
  else
    logger.info "Using maxmind geopoint #{servers_speedtest_maxmind.min_latency} <= #{servers_speedtest_ipstack.min_latency}"
  end
else
  logger.info "servers_speedtest is empty: using ipstack geopoint"
  geopoint = ipstack_geopoint
end

servers_global = manager.sort_and_filter_server_list(servers_global, geopoint,
                                                        keep_num_servers: 20, min_latency: MIN_LATENCY, skip_fqdns: [])
servers_dynamic = manager.sort_and_filter_server_list(servers_dynamic, geopoint,
                                                        keep_num_servers: 20, min_latency: MIN_LATENCY, skip_fqdns: [])

servers = manager.merge_server_lists(servers_speedtest, servers_global)
servers = manager.merge_server_lists(servers, servers_dynamic)
servers.each { |s| logger.debug [ s.url, s.geopoint, s.latency, s.grade, s.graded_latency, s.origin ].ai }

logger.info "Running transfers"
transfers = []
options = { num_threads: 2, download_size: 500, upload_size: 524288, min_transfer_secs: 10, min_latency: MIN_LATENCY }
manager.run_each_transfer(servers, 4, options) do |transfer|
  transfers << transfer
end

transfers.each { |t| puts t.pretty_print }

