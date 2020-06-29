#!/usr/bin/env ruby

require 'logger'
require 'speedtest'
require 'awesome_print'

speedtest = Speedtest::Test.new(min_transfer_secs: 10,
                                download_size: 1000,
                                upload_size: ENV.fetch('UPLOAD_SIZE', 0).to_i,
                                num_threads: ENV.fetch('NUM_THREADS', 10).to_i,
                                logger: Logger.new(STDOUT),
                                skip_servers: [],
                                skip_latency_min_ms: ENV.fetch('SKIP_LATENCY_MIN_MS', 0).to_i,
                                select_server_url: ENV['SELECT_SERVER_URL'],
                                select_server_list: ENV['SELECT_SERVER_LIST'],
                                custom_server_list_url: ENV['SPEEDTEST_URL'],
                                ip_latitude: ENV['LATITUDE'],
                                ip_longitude: ENV['LONGITUDE'],
                                http_lib: ENV.fetch('HTTP_LIB', :httparty).to_sym)

results = speedtest.run
ap results

# Use custom list of speedtest servers
# LATITUDE='34.408' LONGITUDE='-119.720' SPEEDTEST_URL='https://vpsbenchmarks.s3.amazonaws.com/misc/speedtest-us-west.xml' SELECT_SERVER_LIST=custom be bin/speedtest.rb
