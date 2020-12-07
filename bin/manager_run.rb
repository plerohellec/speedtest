#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
manager = Speedtest::Manager.new(logger)

servers_speedtest = manager.load_speedtest_server_list
servers_global = manager.load_global_server_list

speedtest_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip
ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

servers_speedtest = manager.sort_and_filter_server_list(servers_speedtest, speedtest_geopoint,
                                                        keep_num_servers: 20, min_latency: 0, skip_fqdns: [])
servers_global    = manager.sort_and_filter_server_list(servers_global, ipstack_geopoint,
                                                        keep_num_servers: 20, min_latency: 0, skip_fqdns: [])
servers = manager.merge_server_lists(servers_speedtest, servers_global)
servers.each { |s| logger.debug [ s.url, s.geopoint, s.latency ].ai }

transfers = manager.run_transfers(servers, 2, num_threads: 3, download_size: 500, upload_size: 524288)

ap transfers

