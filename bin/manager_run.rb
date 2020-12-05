#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
manager = Speedtest::Manager.new(logger)
servers = manager.load_speedtest_server_list
geopoint = manager.speedtest_geopoint
servers = manager.sort_and_filter_server_list(servers, geopoint, keep_num_servers: 10, min_latency: 0, skip_fqdns: [])
transfers = manager.run_transfers(servers, 2, num_threads: 1, download_size: 2000, upload_size: 524288)
ap transfers

