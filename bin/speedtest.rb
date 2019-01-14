#!/usr/bin/env ruby

require 'logger'
require 'speedtest'

speedtest = Speedtest::Test.new(min_transfer_secs: 2,
                                download_size: 1000,
                                upload_size: 1_000_000,
                                num_threads: 1,
                                logger: Logger.new(STDOUT),
                                skip_servers: [],
                                skip_latency_min_ms: 7,
                                select_server_url: ENV['SELECT_SERVER_URL'])

results = speedtest.run

