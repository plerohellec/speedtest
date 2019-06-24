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

      @ping_runs = 2 if @ping_runs < 2
    end

    def run()
      server = pick_server
      raise FailedTransfer, "Failed to find a suitable server" unless server

      @server_root = server[:url]
      log "Server #{@server_root}"

      latency = server[:latency]

      download_size, download_time = download
      download_rate = download_size / download_time
      log "Download: #{pretty_speed download_rate}"

      upload_size, upload_time = upload
      upload_rate = upload_size / upload_time
      log "Upload: #{pretty_speed upload_rate}"

      Result.new(:server => @server_root, :latency => latency,
        download_size: download_size, download_time: download_time,
        upload_size: upload_size, upload_time: upload_time)
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

    def download
      log "\nstarting download tests:"

      start_time = Time.now
      ring_size = @num_threads * 2
      futures_ring = Ring.new(ring_size)
      download_url = download_url(@server_root)
      pool = TransferWorker.pool(size: @num_threads, args: [download_url, @logger])
      1.upto(ring_size).each do |i|
        futures_ring.append(pool.future.download)
      end

      total_downloaded = 0
      while (future = futures_ring.pop) do
        status = future.value
        raise FailedTransfer.new("Download failed.") if status.error == true
        total_downloaded += status.size

        if Time.now - start_time < @min_transfer_secs
          futures_ring.append(pool.future.download)
        end
      end

      total_time = Time.new - start_time
      log "Took #{total_time} seconds to download #{total_downloaded} bytes in #{@num_threads} threads\n"

      [ total_downloaded * 8, total_time ]
    end

    def randomString(alphabet, size)
      (1.upto(size)).map { alphabet[rand(alphabet.length)] }.join
    end

    def upload_url(server_root)
      "#{server_root}/speedtest/upload.php"
    end

    def upload
      log "\nstarting upload tests:"

      data = randomString(('A'..'Z').to_a, @upload_size)

      start_time = Time.now

      ring_size = @num_threads * 2
      futures_ring = Ring.new(ring_size)
      upload_url = upload_url(@server_root)
      pool = TransferWorker.pool(size: @num_threads, args: [upload_url, @logger])
      1.upto(ring_size).each do |i|
        futures_ring.append(pool.future.upload(data))
      end

      total_uploaded = 0
      while (future = futures_ring.pop) do
        status = future.value
        raise FailedTransfer.new("Upload failed.") if status.error == true
        total_uploaded += status.size

        if Time.now - start_time < @min_transfer_secs
          futures_ring.append(pool.future.upload(data))
        end
      end

      total_time = Time.new - start_time
      log "Took #{total_time} seconds to upload #{total_uploaded} bytes in #{@num_threads} threads\n"

      # bytes to bits / time = bps
      [ total_uploaded * 8, total_time ]
    end

    def pick_server
      page = HTTParty.get("https://www.speedtest.net/api/js/servers?engine=js&https_functional=1")
      servers = JSON.load(page.body)
      sorted_servers = servers.sort_by { |server| server['distance'] }
      sorted_servers = sorted_servers.reject { |server| server['url'].nil? }
      sorted_servers = sorted_servers.map { |server| { url: server['url'] } }

      if @select_server_url
        server = sorted_servers.detect { |x| x[:url] == @select_server_url }
        if server
          server[:latency] = ping(server[:url])
          log "Found selected server: #{server[:url]} latency=#{server[:latency]} distance=#{server[:distance]}"
          return server
        else
          error "Cannot find server #{@select_server_url}"
          return nil
        end
      end

      # sort the nearest 10 by download latency
      latency_sorted_servers = sorted_servers[0..30].map { |x|
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

        if @skip_servers.include?(s[:url])
          log "Skipping #{s} because url in skip list"
          skip = true
        end

        skip
      end

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
        rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED => e
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
  x = Speedtest::Test.new(min_transfer_secs: 10, download_size: 1000, upload_size: 100_000, num_threads: 10, logger: Logger.new(STDOUT), skip_latency_min_ms: 40)
  x.run
end
