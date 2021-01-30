module Speedtest
  module Servers
    class Server
      attr_reader :url, :geopoint, :origin

      NUM_PINGS = 3
      HTTP_PING_TIMEOUT = 5
      DUMMY_GEOPOINT = Speedtest::GeoPoint.new(0,0)

      def initialize(url, geopoint=DUMMY_GEOPOINT, origin=nil)
        @logger = Speedtest.logger
        @url = url
        @geopoint = geopoint
        @origin = origin
      end

      def ==(other)
        self.url == other.url
      end
      alias_method :eql?, :==

      def latency
        calculate_latency unless @latency
        @latency
      end

      def distance(geopoint)
        @geopoint.distance(geopoint)
      end

      def fqdn
        @url.gsub(/https?:\/\/([^\/\:]+).*/, '\1')
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
            @logger.info "ping error: #{e.class} [#{e}] for #{@url}"
            times << 999999
          end
        end
        times.sort
        @latency = times[1, NUM_PINGS].inject(:+) * 1000 / NUM_PINGS # average in milliseconds
      end
    end

    class List < Array

      def initialize
        @logger = Speedtest.logger
      end

      def sort_by_distance(geopoint, keep=nil)
        sorted = List.new
        sorted_list = sort { |a,b| a.distance(geopoint) <=> b.distance(geopoint) }
        sorted_list.each_with_index do |server, i|
          break if keep && i>=keep
          sorted.append(server)
        end
        sorted
      end

      def sort_by_latency
        sorted = List.new
        sorted_list = sort { |a,b| a.latency <=> b.latency }
        sorted_list.each { |server| sorted.append(server) }
        sorted
      end

      def filter(options={})
        filtered = clone

        if options[:min_latency]
          filtered.delete_if { |server| server.latency<options[:min_latency] }
        end

        if options[:skip_fqdns]
          filtered.delete_if { |server| options[:skip_fqdns].include?(server.fqdn) }
        end

        filtered
      end

      def merge(server_list)
        list = clone.concat(server_list)
        list.uniq! { |server| server.url }
        list
      end

      def min_latency
        server = self.min_by(&:latency).latency
      end
    end
  end
end

