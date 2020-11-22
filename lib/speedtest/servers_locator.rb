require_relative 'geo_point'

module Speedtest
  class ServersLocator
    include Logging

    SPEEDTEST_SERVER_LIST_URL = "https://c.speedtest.net/speedtest-servers-static.php"

    def initialize(ipstack_geoip, skip_latency_min_ms)
      @ipstack_geoip = ipstack_geoip
      @skip_latency_min_ms = skip_latency_min_ms
    end

    def speedtest_geoip
      return @speedtest_geoip if @speedtest_geoip
      fetch_speedtest_config
      @speedtest_geoip = geoip_from_speedtest_config
    end

    def sorted_url_latencies(server_list, geoip, max_urls=40)
      sorted_urls = sort_urls_by_geoip(server_list, geoip, max_urls)
      sort_urls_by_latency(sorted_urls, max_urls)
    end

    private

    def fqdn(url)
      url.gsub(/https?:\/\/([^\/\:]+).*/, '\1')
    end

    def sort_urls_by_geoip(server_list, geoip, max_urls=40)
      log "Calculating distances in static server list"
      sorted_servers = server_list.body.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).map do |x|
        {
          distance: geoip.distance(GeoPoint.new(x[1],x[2])),
          url:      x[0].split(/(http:\/\/.*)\/speedtest.*/)[1]
        }
      end
      log "Done calculating distances"
      sorted_servers.reject! { |x| x[:url].nil? }
      sorted_servers.sort_by! { |x| x[:distance] }

      sorted_servers.map { |server| server[:url] }.take(max_urls)
    end

    def sort_urls_by_latency(url_list, max_urls=40)
      log "calculating ping latency for closest 40 servers"
      latency_sorted_servers = url_list.map { |url|
        {
          latency: ping(url),
          url: url
        }
      }.sort_by { |x| x[:latency] }

      latency_sorted_servers.reject! do |s|
        skip = false

        if s[:latency] < @skip_latency_min_ms
          log "Skipping #{s} because latency (#{s[:latency]}) is below threshold (#{@skip_latency_min_ms})"
          skip = true
        end

        skip
      end

      log "Sorted clean servers = #{latency_sorted_servers.inspect}"

      selected = latency_sorted_servers.detect { |s| validate_server_transfer(s[:url]) }
      if selected
        log "Automatically selected server: #{selected[:url]} - #{selected[:latency]} ms"
      else
        error "Cannot find any server matching the requirements"
      end

      selected
    end

    def fetch_speedtest_server_list
      @speedtest_server_list = HTTParty.get(SPEEDTEST_SERVER_LIST_URL)
    end

    def fetch_speedtest_config
      @speedtest_config = HTTParty.get("https://www.speedtest.net/speedtest-config.php")
    end

    def geopip_from_speedtest_config
      ip,lat,lon = @speedtest_config.body.scan(/<client ip="([^"]*)" lat="([^"]*)" lon="([^"]*)"/)[0]

      geo = GeoPoint.new(lat, lon)
      log "Your IP: #{ip}\nYour coordinates: #{geo}\n"
      geo
    end
  end
end

