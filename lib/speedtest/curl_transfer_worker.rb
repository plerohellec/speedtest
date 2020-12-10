require 'celluloid/current'
require 'curl'

module Speedtest
  class CurlTransferWorker
    include Celluloid

    USER_AGENT = 'speedtest-client'

    def initialize(url)
      @url = url
      @logger = Speedtest.logger
    end

    def download
      @logger.info "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl.get(@url) do |c|
          c.timeout = 10
          c.connect_timeout = 2
          c.headers['User-Agent'] = USER_AGENT
        end
        unless page.response_code / 100 == 2
          @logger.error "GET #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.length
      rescue => e
        @logger.error "GET #{@url} failed with exception #{e.class} (#{e})"
        status.error = true
      end
      status
    end

    def upload(content)
      @logger.info "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl::Easy.new(@url) do |c|
          c.timeout = 10
          c.connect_timeout = 2
          c.headers['User-Agent'] = USER_AGENT
        end
        page.http_post(content)

        unless page.response_code / 100 == 2
          @logger.error "POST #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.split('=')[1].to_i
      rescue => e
        @logger.error "POST #{@url} failed with exception #{e.class} (#{e})"
        status.error = true
      end
      status
    end
  end
end
