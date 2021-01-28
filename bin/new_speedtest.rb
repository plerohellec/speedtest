#!/usr/bin/env ruby

require 'amazing_print'

require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

ll = Speedtest::Loaders::ServerList.new("https://c.speedtest.net/speedtest-servers-static.php", :speedtest)
ll.download
servers = ll.parse

#geo = Speedtest::GeoPoint.new(34, -119)
config = Speedtest::Loaders::Config.new
config.load
geo = config.ip_geopoint
logger.info "geo=#{geo.inspect}"

distance_sorted = servers.sort_by_distance(geo, 10)
# distance_sorted.each { |s| ap [ s.url, s.geopoint ] }
latency_sorted = distance_sorted.sort_by_latency
latency_sorted.each { |s| ap [ s.url, s.geopoint, s.latency ] }

filtered = latency_sorted.filter(min_latency: 7,
                                 skip_fqdns: [])
                                 # skip_fqdns: ['speedtest.west.rr.com', 'ookla1.brbnca.sprintadp.net'])

num_transfers = 2
transfers = []
filtered.each do |server|
  logger.info "Starting transfers for #{server.fqdn}"
  mover = Speedtest::Transfers::Mover.new(server, logger, num_threads: 1, download_size: 2000, upload_size: 524288)
  unless mover.validate_server_transfer
    logger.warn "Rejecting #{server.fqdn}"
    next
  end

  transfer = mover.run
  if transfer.failed?
    logger.warn "Transfer for #{server.fqdn} failed: dl=#{transfer.download_size} ul=#{transfer.upload_size}"
    next
  end

  transfers << transfer

  num_transfers -= 1
  break if num_transfers == 0
end

logger.info transfers.ai

