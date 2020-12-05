module Speedtest
  module Transfers
    Transfer = Struct.new(:server, :download_size, :download_time, :upload_size, :upload_time) do
      def failed?
        download_size == 0 || upload_size == 0
      end
    end

    class Mover
      include Speedtest::Logging

      def initialize(server, logger, options={})
        @server = server
        @logger = logger
        @download_size = options[:download_size]         || 4000
        @upload_size   = options[:upload_size]
        @num_threads   = options[:num_threads]           || 10
        @min_transfer_secs = options[:min_transfer_secs] || 10
        @transfer = Transfer.new(@server)
      end

      def run
        download
        upload
        @transfer
      end

      def validate_server_transfer
        downloader = CurlTransferWorker.new(download_url(500), @logger)
        status = downloader.download
        raise RuntimeError if status.error

        uploader = CurlTransferWorker.new(upload_url, @logger)
        data = upload_data(10_000)
        status = uploader.upload(data)
        raise RuntimeError if status.error

        log "Validation success for #{@server.fqdn}"
        true
      rescue => e
        error "Rejecting #{@server.fqdn} - #{e.class} #{e}"
        false
      end

      private

      def download
        log "starting download tests:"

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
            log "Failed download from #{@server.fqdn}"
          else
            total_downloaded += status.size * 8
          end

          if Time.now - start_time < @min_transfer_secs
            futures_ring.append(pool.future.download)
          end
        end

        @transfer.download_size = total_downloaded
        @transfer.download_time = Time.new - start_time

        log "Took #{@transfer.download_time} seconds to download #{total_downloaded} bytes in #{@num_threads} threads\n"
      end

      def upload
        log "starting upload tests:"

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
            log "Failed upload to #{@server.fqdn}"
          else
            total_uploaded += status.size * 8
          end

          if Time.now - start_time < @min_transfer_secs
            futures_ring.append(pool.future.upload(data[rand(data.size)]))
          end
        end

        @transfer.upload_size = total_uploaded
        @transfer.upload_time = Time.new - start_time

        log "Took #{@transfer.upload_time} seconds to upload #{total_uploaded} bytes in #{@num_threads} threads\n"
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
        CurlTransferWorker.pool(size: @num_threads, args: [url, @logger])
      end

      def upload_data(size)
        s = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        content = s * (size / 36.0)
        "content1=#{content}"
      end
    end
  end
end

