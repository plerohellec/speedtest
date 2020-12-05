#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
manager = Speedtest::Manager.new(logger)

servers = manager.load_speedtest_server_list
#servers = manager.load_global_server_list

speedtest_geopoint = Speedtest::GeoPoint.speedtest_geopoint
#local_ip = Speedtest::GeoPoint.local_ip
#ipstack_geopoint = Speedtest::GeoPoint.ipstack_geopoint(local_ip, ENV.fetch('IPSTACK_KEY'))

servers = manager.sort_and_filter_server_list(servers, speedtest_geopoint, keep_num_servers: 10, min_latency: 0, skip_fqdns: [])
transfers = manager.run_transfers(servers, 2, num_threads: 1, download_size: 2000, upload_size: 524288)

ap transfers

