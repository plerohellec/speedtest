module Speedtest
  module Loaders
    class Config
      def load
        @page = Curl.get("https://www.speedtest.net/speedtest-config.php")
        if @page.response_code != 200
          log err = "Server list download failed: code=#{@page.response_code}"
          raise err
        end
      end

      def ip_geopoint
        ip,lat,lon = @page.body_str.scan(/<client ip="([^"]*)" lat="([^"]*)" lon="([^"]*)"/)[0]
        GeoPoint.new(lat, lon)
      end
    end

    class ServerList
      include Speedtest::Logging

      def initialize(url, logger, type)
        @url = url
        @logger = logger
        @type = type
      end

      def download
        @page = Curl.get(@url)
        if @page.response_code != 200
          log err = "Server list download failed: code=#{@page.response_code}"
          raise err
        end
      end

      def parse
        case @type
        when :speedtest then parse_speedtest
        when :global then parse_global
        else
          raise "Unknown server list type: #{@type}"
        end
      end

      private

      def parse_speedtest
        list = Servers::List.new
        @page.body_str.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).each do |x|
          geo = GeoPoint.new(x[1], x[2])
          url = x[0].gsub(/\/speedtest\/.*/, '')
          #log "adding server url: #{url}"
          list << Servers::Server.new(url, geo, @logger)
        end
        list
      end

      def parse_global
        list = Servers::List.new
        regions = YAML.load(@page.body_str)
        regions.each do |region, servers|
          servers.each do |server|
            geo = GeoPoint.new(server['latitude'], server['longitude'])
            url = "http://#{server['url']}"
            list << Servers::Server.new(url, geo, @logger)
          end
        end
        list
      end
    end
  end
end

