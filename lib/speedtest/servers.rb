module Speedtest
  module Servers
    class Server
      attr_reader :url, :geopoint, :origin, :grade

      NUM_PINGS = 3
      HTTP_PING_TIMEOUT = 5
      DUMMY_GEOPOINT = Speedtest::GeoPoint.new(0,0)

      MAX_LATENCY_FOR_BONUS = 12
      MIN_GRADE_FOR_BONUS = 5.20
      LATENCY_BONUS = 0.7

      def initialize(url, geopoint: DUMMY_GEOPOINT, origin: nil, grade: nil)
        @logger = Speedtest.logger
        @url = url
        @geopoint = geopoint
        @origin = origin
        @grade = grade.to_f > 0.0 ? grade.to_f : nil
      end

      def ==(other)
        self.url == other.url
      end
      alias_method :eql?, :==

      def latency
        @latency ||= calculate_average_latency
      end

      def min_latency
        @min_latency ||= calc_min_latency
      end

      def calc_min_latency
        calculate_latencies.min * 1000
      end

      def distance(geopoint)
        @geopoint.distance(geopoint)
      end

      def fqdn
        @url.gsub(/https?:\/\/([^\/\:]+).*/, '\1')
      end

      def graded_latency
        return latency unless origin == :vpsb
        return latency unless (grade && grade > MIN_GRADE_FOR_BONUS)
        return latency if latency > MAX_LATENCY_FOR_BONUS
        latency * LATENCY_BONUS
      end

      private

      def calculate_latencies
        times = []
        0.upto(NUM_PINGS) do
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
        times
      end

      def calculate_average_latency
        latencies = calculate_latencies
        latencies[1, NUM_PINGS].inject(:+) * 1000 / NUM_PINGS # average in milliseconds
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

      def sort_by_graded_latency
        sorted = List.new
        sorted_list = sort { |a,b| a.graded_latency <=> b.graded_latency }
        sorted_list.each { |server| sorted.append(server) }
        sorted
      end

      def filter(options={})
        filtered = clone

        if options[:min_latency]
          filtered.delete_if do |server|
            too_close = (server.min_latency < options[:min_latency])
            @logger.info "Skipping #{server.url} because latency #{server.min_latency}<#{options[:min_latency]}" if too_close
            too_close
          end
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
        return nil if self.none?
        server = self.min_by(&:latency).latency
      end
    end
  end
end

