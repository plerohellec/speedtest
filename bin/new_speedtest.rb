#!/usr/bin/env ruby

require 'amazing_print'

require_relative '../lib/speedtest/servers'

ll = Speedtest::Servers::ListLoader.new("https://c.speedtest.net/speedtest-servers-static.php", Logger.new(STDOUT))
ll.download
servers = ll.parse
geo = Speedtest::GeoPoint.new(34, -119)
distance_sorted = servers.sort_by_distance(geo, 10)
# distance_sorted.each { |s| ap [ s.url, s.geopoint ] }

latency_sorted = distance_sorted.sort_by_latency
latency_sorted.each { |s| ap [ s.url, s.geopoint, s.latency ] }

