#!/usr/bin/env ruby

require 'logger'
require 'speedtest'
require 'awesome_print'

speedtest = Speedtest::Test.new(min_transfer_secs: 5,
                                download_size: 1000,
                                upload_size: 1_000_000,
                                num_threads: 1,
                                logger: Logger.new(STDOUT),
                                skip_servers: [],
                                skip_latency_min_ms: 7,
                                select_server_url: ENV['SELECT_SERVER_URL'],
                                select_server_list: ENV['SELECT_SERVER_LIST'],
                                custom_server_list_url: ENV['SPEEDTEST_URL'])

results = speedtest.run
ap results

