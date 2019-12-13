require 'celluloid/current'

module Speedtest
  class TransferWorker
    include Celluloid
    include Logging

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def download
      # log "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = HTTParty.get(@url, timeout: 10)
        unless page.code / 100 == 2
          error "GET #{@url} failed with code #{page.code}"
          status.error = true
        end
        status.size = page.body.length
      rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "GET #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload(content)
      # log "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = HTTParty.post(@url, :body => { "content" => content }, timeout: 10)
        unless page.code / 100 == 2
          error "POST #{@url} failed with code #{page.code}"
          status.error = true
        end
        status.size = page.body.split('=')[1].to_i
      rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end
  end
end
