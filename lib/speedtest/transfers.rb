module Speedtest
  ThreadStatus = Struct.new(:error, :size)

  module Transfers
    Transfer = Struct.new(:server_url, :latency, :download_size_bytes, :download_time, :upload_size_bytes, :upload_time) do
      def failed?
        download_size_bytes == 0 || upload_size_bytes == 0
      end

      def speed(direction)
        (self["#{direction}_size_bytes"] / self["#{direction}_time"] * 8 / 1_000_000).round
      end

      def pretty_print
        server = server_url.gsub(/https?:\/\/([^\/]+).*/, '\1')
        "#{'%-50s' % server} #{'%5d' % latency.round(2)}ms #{'%6.1f' % speed(:download)}Mbps #{'%6.1f' % speed(:upload)}Mbps"
      end
    end

    class Mover
      def initialize(server, options={})
        @server = server
        @logger = Speedtest.logger
        @download_size = options[:download_size]         || 4000
        @upload_size   = options[:upload_size]
        @num_threads   = options[:num_threads]           || 10
        @min_transfer_secs = options[:min_transfer_secs] || 10
        @transfer = Transfer.new(@server.url, @server.min_latency)
      end

      def run
        download
        upload
        @transfer
      end

      def validate_server_transfer
        downloader = CurlTransferWorker.new(download_url(500))
        status = downloader.download
        raise RuntimeError if status.error

        uploader = CurlTransferWorker.new(upload_url)
        data = upload_data(10_000)
        status = uploader.upload(data)
        raise RuntimeError if status.error

        @logger.info "Validation success for #{@server.fqdn}"
        true
      rescue => e
        @logger.error "Rejecting #{@server.fqdn} - #{e.class} #{e}"
        false
      end

      private

      def download
        @logger.info "starting download tests:"

        start_time = Time.now
        ring_size = @num_threads * 2
        futures_ring = Ring.new(ring_size)
        pool = transfer_worker_pool(download_url(@download_size))
        1.upto(ring_size).each do |i|
          futures_ring.append(pool.future.download)
        end

        total_downloaded = 0
        while (future = futures_ring.pop) do
          status = future.value
          if status.error == true
            @logger.warn "Failed download from #{@server.fqdn}"
          else
            total_downloaded += status.size
          end

          if Time.now - start_time < @min_transfer_secs
            futures_ring.append(pool.future.download)
          end
        end

        @transfer.download_size_bytes = total_downloaded
        @transfer.download_time = Time.new - start_time

        @logger.info "Took #{@transfer.download_time} seconds to download #{total_downloaded} bytes in #{@num_threads} threads\n"
      end

      def upload
        @logger.info "starting upload tests:"

        data = []
        if @upload_size && @upload_size > 0
          data << upload_data(@upload_size)
        else
          data << upload_data(524288)
          data << upload_data(1048576)
          data << upload_data(7340032)
        end

        start_time = Time.now

        ring_size = @num_threads * 2
        futures_ring = Ring.new(ring_size)
        pool = transfer_worker_pool(upload_url)
        1.upto(ring_size).each do |i|
          futures_ring.append(pool.future.upload(data[rand(data.size)]))
        end

        total_uploaded = 0
        while (future = futures_ring.pop) do
          status = future.value
          if status.error == true
            @logger.info "Failed upload to #{@server.fqdn}"
          else
            total_uploaded += status.size
          end

          if Time.now - start_time < @min_transfer_secs
            futures_ring.append(pool.future.upload(data[rand(data.size)]))
          end
        end

        @transfer.upload_size_bytes = total_uploaded
        @transfer.upload_time = Time.new - start_time

        @logger.info "Took #{@transfer.upload_time} seconds to upload #{total_uploaded} bytes in #{@num_threads} threads\n"
      end

      def download_url(size)
        "#{@server.url}/speedtest/random#{size}x#{size}.jpg"
      end

      def upload_url
        if @server.url =~ /upload.php$/
          @server.url
        else
          "#{@server.url}/speedtest/upload.php"
        end
      end

      def transfer_worker_pool(url)
        CurlTransferWorker.pool(size: @num_threads, args: [url])
      end

      def upload_data(size)
        s = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        content = s * (size / 36.0)
        "content1=#{content}"
      end
    end
  end
end

