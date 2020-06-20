require 'httparty'

require_relative 'speedtest/result'
require_relative 'speedtest/geo_point'
require_relative 'speedtest/logging'
require_relative 'speedtest/transfer_worker'
require_relative 'speedtest/ring'

module Speedtest
  ThreadStatus = Struct.new(:error, :size)

  class Test
    include Logging

    class FailedTransfer < StandardError; end
    class NoServerFound < StandardError; end

    HTTP_PING_TIMEOUT = 5

    def initialize(options = {})
      @min_transfer_secs = options[:min_transfer_secs] || 10
      @num_threads   = options[:num_threads]           || 4
      @ping_runs = options[:ping_runs]                 || 4
      @download_size = options[:download_size]         || 4000
      @upload_size = options[:upload_size]             || 1_000_000
      @logger = options[:logger]
      @skip_servers = options[:skip_servers]           || []
      @skip_latency_min_ms = options[:skip_latency_min_ms] || 0
      @select_server_url = options[:select_server_url]
      @select_server_list = options[:select_server_list] # dynamic, static, or custom
      @custom_server_list_url = options[:custom_server_list_url] # needed if select_server_list is custom

      @ping_runs = 2 if @ping_runs < 2
    end

    def run
      server = pick_server
      raise NoServerFound, "Failed to find a suitable server" unless server

      @server_root = server[:url]
      log "Server #{@server_root}"

      latency = server[:latency]

      download_size, download_time = download(@server_root)
      download_rate = download_size / download_time
      log "Download: #{pretty_speed download_rate}"

      upload_size, upload_time = upload(@server_root)
      upload_rate = upload_size / upload_time
      log "Upload: #{pretty_speed upload_rate}"

      server_fqdn = fqdn(@server_root)
      log "server_fqdn = #{server_fqdn}"

      Result.new(:server => server_fqdn, :latency => latency,
        download_size: download_size, download_time: download_time,
        upload_size: upload_size, upload_time: upload_time,
        server_list: @server_list)
    end

    def fqdn(url)
      url.gsub(/https?:\/\/([^\/\:]+)[\/\:].*/, '\1')
    end

    def pretty_speed(speed)
      units = ["bps", "Kbps", "Mbps", "Gbps", "Tbps"]
      i = 0
      while speed > 1024
        speed /= 1024
        i += 1
      end
      "%.2f #{units[i]}" % speed
    end

    def download_url(server_root)
      "#{server_root}/speedtest/random#{@download_size}x#{@download_size}.jpg"
    end

    def download(server_root)
      log "\nstarting download tests:"

      start_time = Time.now
      ring_size = @num_threads * 2
      futures_ring = Ring.new(ring_size)
      download_url = download_url(server_root)
      pool = TransferWorker.pool(size: @num_threads, args: [download_url, @logger])
      1.upto(ring_size).each do |i|
        futures_ring.append(pool.future.download)
      end

      failed = false
      total_downloaded = 0
      while (future = futures_ring.pop) do
        status = future.value
        if status.error == true
          log "Failed download from #{server_root}"
          failed = true
          break
        end
        total_downloaded += status.size

        if Time.now - start_time < @min_transfer_secs
          futures_ring.append(pool.future.download)
        end
      end

      total_time = Time.new - start_time

      if failed
        total_time = 1
        total_downloaded = 0
      else
        log "Took #{total_time} seconds to download #{total_downloaded} bytes in #{@num_threads} threads\n"
      end

      [ total_downloaded * 8, total_time ]
    end

    def randomString(alphabet, size)
      (1.upto(size)).map { alphabet[rand(alphabet.length)] }.join
    end

    def upload_url(server_root)
      if server_root =~ /upload.php$/
        server_root
      else
        "#{server_root}/speedtest/upload.php"
      end
    end

    def upload(server_root)
      log "\nstarting upload tests:"

      data = randomString(('A'..'Z').to_a, @upload_size)

      start_time = Time.now

      ring_size = @num_threads * 2
      futures_ring = Ring.new(ring_size)
      upload_url = upload_url(server_root)
      pool = TransferWorker.pool(size: @num_threads, args: [upload_url, @logger])
      1.upto(ring_size).each do |i|
        futures_ring.append(pool.future.upload(data))
      end

      failed = false
      total_uploaded = 0
      while (future = futures_ring.pop) do
        status = future.value
        if status.error == true
          log "Failed upload to #{server_root}"
          failed = true
          break
        end
        total_uploaded += status.size

        if Time.now - start_time < @min_transfer_secs
          futures_ring.append(pool.future.upload(data))
        end
      end

      total_time = Time.new - start_time

      if failed
        total_time = 1
        total_uploaded = 0
      else
        log "Took #{total_time} seconds to upload #{total_uploaded} bytes in #{@num_threads} threads\n"
      end

      # bytes to bits / time = bps
      [ total_uploaded * 8, total_time ]
    end

    def pick_server
      if @select_server_url
        log "Using selected server #{@select_server_url}"
        servers = [ { url: @select_server_url } ]
        selected = find_best_server(servers)
        @server_list = 'selected' if selected
      end

      if @select_server_list
        log "Using #{@select_server_list} list of servers (requested)"
        selected ||= fetch_list_and_select_server(@select_server_list)
      end

      selected ||= fetch_list_and_select_server('dynamic')
      selected ||= fetch_list_and_select_server('static')
    end

    def fetch_list_and_select_server(server_list)
      log "Using #{server_list} list of servers"
      servers = fetch_server_list(server_list)
      selected = find_best_server(servers)
      @server_list = server_list if selected
      selected
    end

    def fetch_server_list(type)
      case type
      when 'static'
        fetch_custom_server_list("https://c.speedtest.net/speedtest-servers-static.php")
      when 'dynamic'
        fetch_dynamic_server_list
      when 'custom'
        fetch_custom_server_list(@custom_server_list_url)
      else
        raise "Unknown server list #{type}"
      end
    end

    def fetch_dynamic_server_list
      page = HTTParty.get("https://www.speedtest.net/api/js/servers?engine=js&https_functional=1")
      servers = JSON.load(page.body)
      servers.sort_by! { |server| server['distance'] }
      servers.reject! { |server| server['url'].nil? }
      servers.map { |server| { url: server['url'] } }
    end

    def fetch_custom_server_list(url)
      page = HTTParty.get("https://www.speedtest.net/speedtest-config.php")
      ip,lat,lon = page.body.scan(/<client ip="([^"]*)" lat="([^"]*)" lon="([^"]*)"/)[0]
      if ENV['IPSTACK_KEY']
        ips_lat, ips_lon = find_lat_long_from_ipstack(ip)
        if ips_lat
          log "Using geo IP from ipstack (#{ips_lat}, #{ips_lon})"
          lat = ips_lat
          lon = ips_lon
        end
      end

      orig = GeoPoint.new(lat, lon)
      log "Your IP: #{ip}\nYour coordinates: #{orig}\n"

      log "Fetching server list url=#{url}"
      page = HTTParty.get(url)
      log "Calculating distances in static server list"
      sorted_servers = page.body.scan(/<server url="([^"]*)" lat="([^"]*)" lon="([^"]*)/).map { |x| {
        :distance => orig.distance(GeoPoint.new(x[1],x[2])),
        :url => x[0].split(/(http:\/\/.*)\/speedtest.*/)[1]
      } }
      log "Done calculating distances"
      sorted_servers.reject! { |x| x[:url].nil? }
      sorted_servers.sort_by! { |x| x[:distance] }
    end

    def find_lat_long_from_ipstack(ip)
      page = HTTParty.get("http://api.ipstack.com/#{ip}?access_key=#{ENV['IPSTACK_KEY']}")
      if page.code.to_s != '200'
        log "ipstack failed with code #{page.code}"
        return
      end

      data = JSON.load(page.body)
      return data['latitude'], data['longitude']
    end

    def find_best_server(servers)
      log "calculating ping latency for closest 30 servers"
      latency_sorted_servers = servers[0..30].map { |x|
        {
          :latency => ping(x[:url]),
          :url => x[:url]
        }
      }.sort_by { |x| x[:latency] }

      latency_sorted_servers.reject! do |s|
        skip = false

        if s[:latency] < @skip_latency_min_ms
          log "Skipping #{s} because latency (#{s[:latency]}) is below threshold (#{@skip_latency_min_ms})"
          skip = true
        end

        if @skip_servers.include?(fqdn(s[:url]))
          log "Skipping #{s} because url in skip list"
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

    def validate_server_transfer(server_root)
      downloader = TransferWorker.new(download_url(server_root), @logger)
      status = downloader.download
      raise RuntimeError if status.error

      uploader = TransferWorker.new(upload_url(server_root), @logger)
      data = randomString(('A'..'Z').to_a, @upload_size)
      status = uploader.upload(data)
      raise RuntimeError if status.error || status.size < @upload_size

      true
    rescue => e
      log "Rejecting #{server_root}"
      false
    end

    def ping(server)
      times = []
      1.upto(@ping_runs) {
        start = Time.new
        begin
          page = HTTParty.get("#{server}/speedtest/latency.txt", timeout: HTTP_PING_TIMEOUT)
          times << Time.new - start
        rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET, SocketError => e
          log "ping error: #{e.class} [#{e}] for #{server}"
          times << 999999
        end
      }
      times.sort
      times[1, @ping_runs].inject(:+) * 1000 / @ping_runs # average in milliseconds
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  x = Speedtest::Test.new(min_transfer_secs: 10, download_size: 1000, upload_size: 100_000, num_threads: 10, logger: Logger.new(STDOUT), skip_latency_min_ms: 7)
  x.run
end
