#!/usr/bin/env ruby

# URL='speedgauge2.optonline.net:8080' bundle exec bin/run_single.rb

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)

server = Speedtest::Servers::Server.new(ENV.fetch('URL'), Speedtest::GeoPoint.new(0,0), @logger)
options = { num_threads: 2, download_size: 500, upload_size: 524288 }
mover = Speedtest::Transfers::Mover.new(server, @logger, options)
transfer = mover.run
ap transfer

