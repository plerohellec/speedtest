require 'logger'
require 'curl'

require_relative 'logging'
require_relative 'geo_point'

module Speedtest
  module Servers
    class Server
      include Speedtest::Logging

      attr_reader :url, :geopoint

      NUM_PINGS = 3
      HTTP_PING_TIMEOUT = 5

      def initialize(url, geopoint, logger)
        @logger = logger
        @url = url
        @geopoint = geopoint
      end

      def latency
        calculate_latency unless @latency
        @latency
      end

      def distance(geopoint)
        @geopoint.distance(geopoint)
      end

      private

      def calculate_latency
        return if @latency

        times = []
        1.upto(NUM_PINGS) do
          start = Time.new
          begin
            Curl.get("#{@url}/speedtest/latency.txt") do |c|
              c.timeout = HTTP_PING_TIMEOUT
              c.connect_timeout = HTTP_PING_TIMEOUT
            end
            times << Time.new - start
          rescue => e
            log "ping error: #{e.class} [#{e}] for #{@url}"
            times << 999999
          end
        end
        times.sort
        @latency = times[1, NUM_PINGS].inject(:+) * 1000 / NUM_PINGS # average in milliseconds
      end
    end

    class List
      def initialize
        @list = []
      end

      def clone
        newlist = List.new
        @list.each { |server| newlist.append(server) }
        newlist
      end

      def append(server)
        @list << server
      end

      def each(&block)
        @list.each do |server|
          yield server
        end
        nil
      end

      def sort_by_distance(geopoint, keep=50)
        sorted = List.new
        sorted_list = @list.sort_by { |server| server.distance(geopoint) }
        sorted_list.each_with_index do |server, i|
          break if i>=keep
          sorted.append(server)
        end
        sorted
      end

      def sort_by_latency
        sorted = List.new
        sorted_list = @list.sort_by { |server| server.latency }
        sorted_list.each { |server| sorted.append(server) }
        sorted
      end

      def merge(server_list)
        merged = self.clone
        server_list.each { |server| merged.append(server) }
        merged
      end
    end

    class ListLoader
      include Speedtest::Logging

      def initialize(speedtest_url, logger)
        @speedtest_url = speedtest_url
        @logger = logger
      end

      def download
        @page = Curl.get(@speedtest_url)
        if @page.response_code != 200
          err = "Server list download failed: code=#{@page.response_code}"
          log err
          raise err
        end
      end

      def parse
        list = List.new
        @page.body_str.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).each do |x|
          geo = GeoPoint.new(x[1], x[2])
          url = x[0].gsub(/\/speedtest\/.*/, '')
          list.append(Server.new(url, geo, @logger))
        end
        list
      end
    end
  end
end

