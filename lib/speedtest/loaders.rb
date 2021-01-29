module Speedtest
  module Loaders
    class Config
      def load
        @page = Curl.get("https://www.speedtest.net/speedtest-config.php")
        if @page.response_code != 200
          Speedtest.logger.error err = "Server list download failed: code=#{@page.response_code}"
          raise err
        end
      end

      def ip_geopoint
        ip,lat,lon = @page.body_str.scan(/<client ip="([^"]*)" lat="([^"]*)" lon="([^"]*)"/)[0]
        GeoPoint.new(lat, lon)
      end
    end

    class ServerList
      def initialize(url_or_path, origin)
        @url_or_path = url_or_path
        @logger = Speedtest.logger
        @origin = origin
      end

      def download
        case @origin
        when :speedtest, :dynamic
          resp = Curl.get(@url_or_path)
          if resp.response_code != 200
            @logger.error err = "Server list download failed: code=#{resp.response_code}"
            raise err
          end
          @page = resp.body_str
        when :global
          @page = File.read(@url_or_path)
        else
          raise "Unknown server list origin: #{@origin}"
        end
      end

      def parse
        case @origin
        when :speedtest then parse_speedtest
        when :global then parse_global
        when :dynamic then parse_dynamic
        else
          raise "Unknown server list origin: #{@origin}"
        end
      end

      private

      def parse_speedtest
        list = Servers::List.new
        @page.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).each do |x|
          geo = GeoPoint.new(x[1], x[2])
          url = x[0].gsub(/\/speedtest\/.*/, '')
          list << Servers::Server.new(url, geo, @origin)
        end
        list
      end

      def parse_global
        list = Servers::List.new
        regions = YAML.load(@page)
        regions.each do |region, servers|
          servers.each do |server|
            geo = GeoPoint.new(0, 0)
            url = "http://#{server['url']}"
            list << Servers::Server.new(url, geo, @origin)
          end
        end
        list
      end

      def parse_dynamic
        servers = JSON.load(@page)
        servers.sort_by! { |server| server['distance'] }
        servers.reject! { |server| server['url'].nil? }

        list = Servers::List.new
        servers.each do |server|
          geo = GeoPoint.new(server['lat'], server['lon'])
          list << Servers::Server.new(server['url'], geo, @origin)
        end
        list
      end
    end
  end
end

