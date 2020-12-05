module Speedtest
  class GeoPoint
    class << self
      def speedtest_geopoint
        config = Speedtest::Loaders::Config.new
        config.load
        config.ip_geopoint
      end

      def local_ip
        page = Curl.get('https://api.ipify.org')
        if page.response_code != 200
          raise "ipify failed with code #{page.response_code}"
        end

        page.body_str
      end

      def ipstack_geopoint(ip, ipstack_key)
        page = Curl.get("http://api.ipstack.com/#{ip}?access_key=#{ipstack_key}")
        if page.response_code != 200
          raise "ipstack failed with code #{page.response_code}"
        end

        body = JSON.load(page.body_str)
        if body['success'] == false
          raise "ipstask error: #{body}"
        end

        GeoPoint.new(body['latitude'], body['longitude'])
      end
    end

    attr_accessor :lat, :lon

    def initialize(lat, lon)
      @lat = Float(lat)
      @lon = Float(lon)
    end

    def to_s
      "[#{lat}, #{lon}]"
    end

    def distance(point)
      Math.sqrt((point.lon - lon)**2 + (point.lat - lat)**2)
    end
  end
end
