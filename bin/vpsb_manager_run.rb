#!/usr/bin/env ruby

require 'amazing_print'
Bundler.require
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new

# Uncomment vpsb_client from Gemfile to use data from VPSB server
vpsb_config = '/home/philippe/src/uupdates/config/vpsb.yml'
if Object.const_defined?('VpsbClient::Manager') && File.exists?(vpsb_config)
  logger.info "Loading servers list from VPSB"
  vpsb_client = VpsbClient::Manager.new(vpsb_config, logger)
  vpsb_client.setup
  vpsb_data = vpsb_client.get_speedtest_servers_by_region
else
  logger.info "Loading servers list from string"
  vpsb_data = JSON.parse('{"eu-west":[{"host":"speedtest.eu.kamatera.com:8080","lat":"44.0","lon":"2.0"}],"us-east":[{"host":"ashburn.speedtest.shentel.net","lat":"48.0","lon":"-90.0"}],"us-west":[{"host":"reflector.aberythmic.com:8080","lat":"34.0","lon":"-122.0"}]}')
end
servers = manager.load_vpsb_server_list(vpsb_data)

logger.info "Sorting servers lists"
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
local_ip = Speedtest::GeoPoint.local_ip

servers_maxmind = manager.sort_and_filter_server_list(servers, maxmind_geopoint,
                                                        keep_num_servers: 20, min_latency: 2, skip_fqdns: [])

geopoint = maxmind_geopoint
servers = servers_maxmind

servers.each { |s| logger.debug [ s.url, s.geopoint, s.latency, s.grade, s.graded_latency ].ai }

logger.info "Running transfers"
manager.run_each_transfer(servers, 2, num_threads: 2, download_size: 500, upload_size: 524288) do |transfer|
  logger.debug transfer.pretty_print
end

logger.info "Errors:"
logger.info manager.error_servers.ai

