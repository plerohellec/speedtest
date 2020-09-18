require 'celluloid/current'
require 'curl'

module Speedtest
  class CurlTransferWorker
    include Celluloid
    include Logging

    USER_AGENT = 'speedtest-client'

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def download
      # log "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl.get(@url) do |c|
          c.timeout = 10
          c.connect_timeout = 2
          c.headers['User-Agent'] = USER_AGENT
        end
        unless page.response_code / 100 == 2
          error "GET #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.length
      rescue Curl::Err::ConnectionFailedError, Curl::Err::TimeoutError, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "GET #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload(content)
      # log "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl::Easy.new(@url) do |c|
          c.timeout = 10
          c.connect_timeout = 2
          c.headers['User-Agent'] = USER_AGENT
        end
        page.http_post(content)

        unless page.response_code / 100 == 2
          error "POST #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.split('=')[1].to_i
      rescue Curl::Err::ConnectionFailedError, Curl::Err::TimeoutError, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end
  end
end
