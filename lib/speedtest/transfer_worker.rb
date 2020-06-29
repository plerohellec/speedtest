require 'celluloid/current'
require 'curl'

module Speedtest
  class TransferWorker
    include Celluloid
    include Logging

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def download_curl
      # log "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl.get(@url) do |c|
          c.timeout = 10
          c.connect_timeout = 10
        end
        unless page.response_code / 100 == 2
          error "GET #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.length
      rescue Curl::Err::TimeoutError, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "GET #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def download_httparty
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

    def upload_curl(content)
      # log "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl::Easy.new(@url) do |c|
          c.timeout = 15
          c.connect_timeout = 1
        end
        page.http_post(content)

        unless page.response_code / 100 == 2
          error "POST #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.split('=')[1].to_i
      rescue Curl::Err::TimeoutError, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload_httparty(content)
      #log "  uploading: #{@url} size: #{content.size}"
      status = ThreadStatus.new(false, 0)

      begin
        page = HTTParty.post(@url, :body => { "content1" => content }, timeout: 10)
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
