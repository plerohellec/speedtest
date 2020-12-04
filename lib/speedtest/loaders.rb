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

      def initialize(speedtest_url, logger)
        @speedtest_url = speedtest_url
        @logger = logger
      end

      def download
        @page = Curl.get(@speedtest_url)
        if @page.response_code != 200
          log err = "Server list download failed: code=#{@page.response_code}"
          raise err
        end
      end

      def parse
        list = Servers::List.new
        @page.body_str.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).each do |x|
          geo = GeoPoint.new(x[1], x[2])
          url = x[0].gsub(/\/speedtest\/.*/, '')
          list.append(Servers::Server.new(url, geo, @logger))
        end
        list
      end
    end
  end
end

